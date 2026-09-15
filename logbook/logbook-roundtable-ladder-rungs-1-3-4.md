# Logbook: roundtable ladder rungs 1, 3 and 4

Question: what does the store's YCSB workload F path cost, where does
the time go, and how much of the operator's ~400 ops/s number for the
SQLite+FDB path is fixable in the store rather than in the caller.

## The apparatus

The operator's launch line is what set the baseline:

    -db site.ycsb.db.JdbcDBClient -s -P ../workloads/workloadf \
      -p db.driver=org.sqlite.JDBC \
      -p db.url=jdbc:sqlite:file:/tmp/ycsb.db?vfs=weft_fdb&journal_mode=MEMORY \
      -p jdbc.autocommit=true -p db.batchsize=1000 -t

The store: `6-datasource/store` at HEAD of the ladder branch. The FDB
substrate: `weftspun-fdb` on Fly, region sjc, three `shared-cpu-2x`
machines, FDB 7.3.76, TLS on. The measurement machines below.

## The measurements

### Rung 0. The FDB substrate itself

Not a YCSB run. `fdbcli --exec 'status json'` on `weftspun-fdb`'s
first coordinator, extracted from `latency_probe` and the per-role
`*_latency_statistics` in the last-minute window:

|                                  | value    | vs. gist same-DC RTT (500 µs) |
| -------------------------------- | -------- | ------------------------------ |
| `latency_probe.read_seconds`     | 1293 µs  | 2.6× a same-DC RTT             |
| `latency_probe.commit_seconds`   | 5781 µs  | 11.6× a same-DC RTT            |
| `latency_probe.transaction_start_seconds` (GRV) | 3933 µs | 7.9×    |
| storage `read_latency_statistics` mean         | 86–92 µs |                           |
| storage `read_latency_statistics` p99          | 224–566 µs |                         |
| commit_proxy `commit_latency_statistics` mean  | 5.2–5.9 ms |                         |
| commit_proxy `commit_latency_statistics` p99   | 4.7–6.5 ms |                         |
| commit_proxy `commit_latency_statistics` max   | 6.9–12.9 ms |                        |

So the client-observed one-shot read floor on this cluster is ~1.3 ms
(one same-DC RTT + storage server ~90 µs + serialisation), and the
client-observed commit floor is ~5.8 ms (GRV + resolver + tlog fsync).
Anything **per-op** that hits the commit path is bounded below by that
5.8 ms; the ladder can move the read floor and can amortise the commit
floor across many ops, but cannot make one commit faster than what the
cluster itself already runs internally.

### Rung 0b. Local Postgres A/B (an unrelated but useful control)

Same operator command line, Postgres 16 on this desk over Unix socket,
100 k ops workload F, 1000 rows loaded:

| flag                                    | ops/s    | READ p99 | RMW p99 |
| --------------------------------------- | -------- | -------- | ------- |
| `-p jdbc.autocommit=true`               | 18,993   | 40 µs    | 180 µs  |
| `-p jdbc.autocommit=false -p db.batchsize=1000` | 13,814 | 172 µs  | 440 µs  |

The autocommit=false variant is **–27% throughput** on Postgres
loopback, exactly the opposite of what the "flip autocommit" hypothesis
predicted for the FDB path. Explanation: Postgres commit here is ~50 µs
because fsync is queued, so the BEGIN/COMMIT round-trip protocol
overhead of autocommit=false exceeds the savings. The
autocommit=false win only appears when the commit floor is expensive :
5.8 ms on this FDB cluster, and there it is ~10× (predicted, not yet
measured against a Rung-1 store. See below). The point of recording
Postgres here is that the same knob has different signs on different
substrates, so "flip autocommit" is not a general recommendation.

### Rungs 1, 3, 4. What changed and what did not

The C landed and compiles clean; the Lean proofs land alongside each.
End-to-end YCSB against the ladder branch has not been run. See "What
this does not settle" below.

**Rung 1: pipeline PIDX and DELTA(HEAD) inside `page_from_store`.**
The two-row read was sequential. One round trip for PIDX, then one for
DELTA/SHARD. Rung 1 issues both futures at once and uses the
speculative DELTA(HEAD) when PIDX names HEAD (the hot case under YCSB
Zipfian). Miss case falls back to sequential. Both keys land in the
FDB read-conflict set exactly as before; the correctness argument is
`spec/PipelinedRead.sequential_read_set_subset_pipelined`. Halves the
per-read round-trip count for warm workloads. Predicted read floor
after Rung 1: ~0.65 ms (one RTT + storage server) instead of ~1.3 ms.

**Rung 2: RETRACTED.** The plan was to coalesce concurrent `xSync`
calls on one file into one FDB commit. Three problems named in the
plan file and preserved here so the retraction stays with what it
retracts:

  1. `locking_mode=EXCLUSIVE` serialises one file to one thread. The
     operator's `-t` (single-thread) run has no second xSync in the
     window. Nothing to coalesce.
  2. Deferring xSync's return until a later commit violates SQLite's
     durability contract: xSync's return is the ACK.
  3. Cross-`FdbFile` merging (different avatars) preserves isolation
     but couples one actor's abort/retry to another's.

The real group-commit pattern (Postgres `commit_delay`) needs
concurrent writers on distinct connections, which is what the
per-avatar-per-core harness `store.cpp` foreshadows but has not
written yet. Left as an RFD.

**Rung 3: `PRAGMA cache_size = -262144` (256 MiB) in the loadable
extension.** `fdb_vfs_ext.c` registers a `sqlite3_auto_extension`
callback that sets the pragma on every new connection whose main VFS is
`weft_fdb`. The correctness argument: SQLite trunk is single-writer per
file, `locking_mode=EXCLUSIVE` is already required
(`fdb_vfs.c:49`), and every distributed-SQLite in production
(LiteFS, rqlite, dqlite, Turso) sits on the same contract, so
trusting SQLite's cache across statements is what the existing design
already does. Rung 3 enlarges an already-trusted cache from SQLite's
default 2 MiB to 256 MiB. `cache_spill = 0` deliberately not touched
(it would gain nothing under weft_fdb and could turn a large
transaction into `SQLITE_FULL`). Adds no new hazard.

**Rung 4: coalesce `buffer_page`'s partial-write prerequisite read
into the read-ahead window.** `fdb_vfs.c:buffer_page` opened a fresh
FDB transaction just to read one page before applying a partial
write. Under YCSB workload F every RMW hit this. Rung 4 checks
`ra_hit` first; on a window hit, the pre-write read is served from
memory and one whole FDB transaction goes away. Correctness turns on
window freshness (`ra_reset` fires on every event that could change
the store), which is the property
`spec/PrewriteCoalesce.stale_window_lies_on_the_write_side` names.

## The retractions this run made stick

- **The snapshot-read rung** an early draft proposed for `read_body`
  is not on the ladder. Workload F is RMW; a snapshot read drops the
  row from the FDB transaction's read-conflict set, so a concurrent
  commit against the same row lands unnoticed and the modify writes
  on top of a stale value. Silent lost update, exactly the failure
  the fence was added to catch. Serialisable reads are the property
  the store rests on.

- **The "just flip autocommit=false" recommendation** is not a
  general answer. Refuted by the Postgres A/B above: the win's sign
  is set by the commit floor cost, not by the flag.

- **HCTree** as a path to concurrent writers per SQLite file is not
  on any roadmap here. Experimental, no production users, and the
  MMO shape shards by avatar/zone anyway, which does not need it.
  See `~/.claude/projects/.../memory/sqlite-is-architecturally-single-writer.md`.

- **Comdb2's BOCC / row-locking / BerkeleyDB-fork approach** is
  parked. The paper (Scotti et al., VLDB 2016) is a reference for
  the coordination stack. Which weft already inherits from FDB :
  not a template for extending SQLite. Comdb2's storage is
  BerkeleyDB, not SQLite (§4.1).
  See `~/.claude/projects/.../memory/multi-writer-design-crdb-adopted-comdb2-parked.md`.

- **CRDB Parallel Commits** is adopted as the cross-shard atomic
  protocol. Already formalised in
  `6-datasource/store/spec/ParallelCommit.lean` (509 lines, mapping
  table, proved theorems). No further work here beyond naming it as
  the answer for the multi-actor case.

## What this does not settle

- **End-to-end YCSB against the ladder branch has not been run.**
  The predicted numbers above come from the FDB canary probes and
  the two-round-trip layout of the pre-Rung-1 read path; they are
  not a substitute for a real run. Standing that run up needs one of:
  the Fly harness (~half day of engineering: OpenJDK + YCSB 0.17.0
  + `V-Sekai-fire/sqlite-jdbc` with the baked-in `weft_fdb` VFS +
  FDB TLS certs as Fly secrets + local Postgres in the same image),
  or a single-node local FDB in docker (~2 hours, but the numbers do
  not map to same-DC RTT). Either fills in a row per rung under
  the same command line the operator posted.

- **Rung 2's genuine successor**. Cross-actor group-commit in the
  per-avatar-per-core harness. Is not written. The Lean model is
  ready (`spec/GroupCommit.lean` has `merged_commit_read_set_is_union`,
  `merged_commit_aborts_on_any_conflict`, and
  `merged_writes_equal_sequential_writes`). The C waits for
  `store.cpp`'s harness to have multiple writers to coalesce.

- **The MMO-scale property**. Per-actor p99 under one tick (≤ 16 ms
  at 60 Hz, ≤ 8 ms at 128 Hz) at 10 k concurrent actors. Is not
  checked. `store_driver.cpp` measures the shape (commits in flight
  worth 44× per the earlier logbook entry), but that number was
  recorded before Rungs 1/3/4 and does not yet reflect them.

## What the ladder does settle, in prose

Per-avatar read latency has a Lean-proved lower-round-trip path
(Rung 1) and a large trusted local cache (Rung 3), and the RMW
pre-write read no longer opens a transaction of its own (Rung 4).
Concurrent-writers-per-DB. The axis Comdb2 and HCTree address. Is
not the axis MMO FPS scales on, and the design already sharded by
avatar and inherits FDB's coordination stack for the cross-shard
case. The one remaining scale item, cross-actor group-commit, is a
harness-side RFD with a ready Lean model, not a VFS-side rung.
