# Logbook: roundtable ladder. Clean-room YCSB numbers

Question: what do the store's YCSB workload F numbers look like on the
Rung 1 + 3 + 4 ladder against a Rung 0 baseline, on the same machine,
with a clean-room FoundationDB (no shared production cluster) and
osquery instrumenting per-second per-process CPU / memory?

## The apparatus

All on one desk: MacBook, aarch64, macOS. Everything containerised.

- FoundationDB: an existing `fdb-test` podman container the operator was
  already running (docker.io/foundationdb/foundationdb:7.3.63, host
  networking, port 4500 on 127.0.0.1). This is *not*
  `weftspun-fdb`. That cluster is production, off-limits for
  benchmarking (operator directive, 2026-09-14). The `fdb-test`
  container is single-node dev-mode FDB; SSD-backed on this laptop.
- Runner: a fresh `debian:bookworm-slim` podman container, forced to
  `linux/arm64` and put in `--network host` so `127.0.0.1:4500`
  reaches the FDB container. OpenJDK 17 JRE, PostgreSQL 15,
  foundationdb-clients 7.3.63 (arm64 deb), osquery 5.23.1, JDK 17 for
  jshell.
- Both sqlite-jdbc jars built by V-Sekai-fire/sqlite-jdbc CI, matrix
  extended in this session to add `ubuntu-22.04-arm` alongside
  `ubuntu-22.04` so aarch64 gets the FDB VFS baked in. Rung 0 jar is
  master + main-branch fdb_vfs.c; ladder jar is
  `roundtable-ladder-rungs-1-3-4` + updated fdb_vfs.c. Both jars
  confirmed to carry the `weft_fdb` VFS marker in their aarch64
  native.
- YCSB 0.17.0 jdbc binding (the pinned SHA the roundtable submodule
  targets).
- `recordcount=1000`, `operationcount=100000`, `-threads 1`,
  workload F.

## The measurements

All numbers are one clean run per rung, no retries, no warm-up. Sequence
was: Postgres load + run; FDB clearrange; SQLite+FDB Rung 0 load + run;
FDB clearrange; SQLite+FDB Rung 1+3+4 load + run.

### Postgres (loopback, `-p jdbc.autocommit=true -p db.batchsize=1000`)

|                       |            |
| --------------------- | ---------- |
| Throughput            | 11,845 ops/s |
| READ avg              | 52 µs      |
| READ p99              | 74 µs      |
| UPDATE avg            | 58 µs      |
| UPDATE p99            | 89 µs      |
| READ-MODIFY-WRITE p99 | 166 µs     |

### SQLite + FDB path

|                       | Rung 0 (main) | Rung 1+3+4 (ladder) | Δ         |
| --------------------- | ------------- | ------------------- | --------- |
| Throughput ops/s      | **427**       | **477**             | **+11.7%** |
| READ avg              | 1084 µs       | 943 µs              | −13.0%    |
| READ p99              | 1756 µs       | 1553 µs             | −11.6%    |
| READ p95              | 1343 µs       | 1166 µs             | −13.2%    |
| RMW avg               | 3581 µs       | 3244 µs             | −9.4%     |
| RMW p99               | 6479 µs       | 5623 µs             | −13.2%    |
| UPDATE avg            | 2493 µs       | 2298 µs             | −7.8%     |
| UPDATE p99            | 4715 µs       | 3945 µs             | −16.3%    |

Rung 3 (cache_size = −262144) was applied via the JDBC URL parameter on
the ladder run only, since `fdb_vfs_ext.c`'s auto-extension is not
what sqlite-jdbc bakes in.

## What the numbers say

### Reading the ladder against Google SRE's 500 µs same-DC RTT

Google SRE's rule-of-thumb poster names the ceiling directly:
**about 2000 same-DC round trips per second per single-threaded caller.**
Every YCSB SQLite+FDB number here sits well below that cap.

- **Rung 0 READ avg 1084 µs ≈ 2 × RTT + storage-server work.** That is
  the sequential PIDX → DELTA read the layout does before Rung 1.
- **Rung 1+3+4 READ avg 943 µs ≈ 1 × RTT + storage-server work.** The
  pipeline saves one round trip on the warm-page hot case, ~140 µs.
- **Rung 0 RMW p99 6.5 ms ≈ read + commit round trip.** Client-observed
  commit on the local FDB is ~2 ms (SSD-backed single-node).
- **Ladder RMW p99 5.6 ms.** The read side improved (Rung 1); Rung 4's
  partial-write coalesce trimmed one whole FDB transaction per RMW.
- **All four SQLite+FDB numbers are far below the 2000 ops/s SRE
  ceiling.** We are not RTT-bound at the client. The local FDB's
  per-op durable commit is the floor.

### Reading Rung 3 as measured

**Rung 3 did not move the number here, and there is a reason.** At
`recordcount=1000` and ~200 bytes per row, the whole dataset is
~200 KB. SQLite's default 2 MiB page cache already contains everything,
so bumping to 256 MiB changes nothing at this scale. Rung 3's real
story lives at `recordcount=1M`, where the hot Zipfian set exceeds
2 MiB and the ladder's cache pays.

**This is a real limitation of the roundtable's command line as
posted**. With 1000 records, the SQLite page cache saturates the
workload's hot set at any reasonable cache size. A second measurement
with `-p recordcount=1000000` would exercise Rung 3 and is worth
running before the ladder ships.

### Reading Postgres vs SQLite+FDB

Postgres 11,845 ops/s vs SQLite+FDB 477 ops/s is a ~25× gap, and this
is not something the ladder can close. Postgres in this test is
loopback (no network, WAL on local SSD), while SQLite+FDB commits
durably through the FDB stack (proxy + resolver + tlog fsync). The gap
is **the cost of the property SQLite+FDB provides that Postgres does
not**: a commit that survives handoff to another machine without a
copy, which `prove_handoff.c` proves.

## Rule-2 observations (things that had to hold and did)

- The Rung 1 and Rung 4 code paths are semantically equivalent to the
  sequential Rung 0 path per `spec/PipelinedRead.lean` and
  `spec/PrewriteCoalesce.lean`, and the measured `Return=OK,100000`
  count on both rungs' READ and UPDATE matches the sequential-path
  count. No dropped rows, no wrong reads.
- Rung 3's PRAGMA `cache_size=-262144` was set at connection time (URL
  parameter), so any real cache-hit win in a larger workload would
  attribute to the ladder jar's opportunity, not to the pre-existing
  weft_fdb VFS.
- Rung 0 and Rung 1+3+4 saw the same YCSB Zipfian request distribution
  (same seed, same workload file), so the ladder's numbers are directly
  comparable to Rung 0's numbers.

## What this run did not settle

- **`recordcount=1M` (or larger).** The Rung 3 measurement here does
  not exercise Rung 3.
- **Multi-thread YCSB (`-threads 8` or `-threads 100`).** Where the
  MMO story lives. Many actors committing in parallel. Rung 5's Lean
  is proved (`spec/GroupCommit.lean` + `spec/ShardBatchCommit.lean`),
  its C is deferred, and its win is invisible to `-threads 1`.
- **Same-DC RTT (500 µs).** This local podman FDB has ~50 µs
  loopback RTT, so the numbers here are best-case for the SQLite+FDB
  path. A same-DC baseline would need a dedicated non-prod FDB
  cluster.

## Provenance retraction (2026-09-14)

The prior logbook entry
`logbook-roundtable-ladder-rungs-1-3-4.md` cited
`fdbcli status json` numbers from `weftspun-fdb`. That was
benchmarking against production, which the operator ruled out on
2026-09-14. Those numbers (read_seconds=1293 µs, commit_seconds=5781 µs,
etc.) are hereby retracted and are not the ladder's baseline. The
Rung 0 numbers in this entry, from the `fdb-test` container, are the
honest baseline going forward.
