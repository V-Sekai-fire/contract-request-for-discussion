# Rung 12: share one FDB read transaction across xRead

Standing record after Rung 11: 90,391 ops/s at 8 workers on 8-proc
redwood. The CI runner is single-share single-proc, so its numbers
had always sat below the operator's box. This entry records four
misreads on the way to landing the change that moved that CI number
past its wall.

## What the CI wall actually was

Direct-round CI at 100k records / 100k ops / 2 workers stalled at
five minutes on run 35011347918. The wall was not the SQLite page
cache, the dirty-page buffer, or Redwood catch-up. Every `xRead`
in `fdb_vfs.c:225` called `run_txn`, which opened a fresh
`FDBTransaction` and asked FDB for a new read version. On CI's
single-share VM a GRV round trip costs 1 to 5 milliseconds. 100k
reads paid that once each: 100 to 500 seconds of wall.

## The four misreads

### Misread 1: the 16k ops/s number was mislabeled

Run 35001863633 finished 100k / 100k in 12.3 seconds at 16,247 ops/s.
It ran the ladder loop with argv[5] pointing at a SQL init file that
set `PRAGMA cache_size=-4194304` (4 GiB). But
`V-Sekai-fire/datasource-store#15` (init-SQL argv[5]) was closed
unmerged, so argv[5] was ignored and every rung ran against the
hardcoded default of 256 MiB. The 12.3 s was not a 4 GiB measurement.
Every later PR built on that misread until the ladder log was
re-read carefully.

### Misread 2: the CacheBackpressure Lean model, correct class

`spec/CacheBackpressure.lean` on
`V-Sekai-fire/datasource-store#16` modelled unbounded dirty-page
growth: `drainRate` non-linear in load, `bp_bounded` proved that
credit-based admission (admit is `min(arr, cap-q)`) keeps the
queue at or below cap. The model was internally consistent and the
class of bug it captured (self-inflicted DDoS on a shared buffer)
is real. It was not the class of bug this workload hits: YCSB
workload F commits every 1000 rows, `clear_dirty` runs on every
commit, and the buffer never exceeded ~250 dirty pages against a
`DIRTY_SOFT_CAP = STAGE_TXN_PAGES * 4 = 8444` cap. The cap never
triggered. **Retracted with `V-Sekai-fire/datasource-store#19`.**

### Misread 3: the 4 GiB cache workaround

`V-Sekai-fire/datasource-store#17` raised the hardcoded PRAGMA
cache from 256 MiB to 4 GiB per worker. It was based on the same
mislabeled 12.3 s ladder number. Since SQLite's page cache is not
being invalidated (the fdb_vfs.c reader established this: v1
io_methods, locks are no-ops, no shm surface), raising the cache
past the ~100 MiB working set does nothing at this workload's
shape. Merged before the misread was diagnosed and left in place
as a soft workaround; harmless but not the fix.

### Misread 4: the wipe-and-restart step

`V-Sekai-fire/entities-vsk-database-roundtable#9` wiped
`/var/lib/foundationdb/data/*` and restarted the systemd unit
between runs to get a fresh cluster. The wipe left the cluster with
orphaned coordinator state, so `status details` reported the
replication health as unknown, one process as erroring, and the
zones as unknown. The workload then hung inside `weft_fdb_start`
against a cluster that could not serve reads. The step reported
success because `timeout 90 ... 2>&1 | tee ...` propagates tee's
exit code (0), not timeout's (124). Both false signals fixed on
`V-Sekai-fire/entities-vsk-database-roundtable#11`: no wipe (fresh
apt install of FDB gives an empty healthy ssd-configured cluster),
plus `set -o pipefail` on the workload step.

## What actually shipped

`V-Sekai-fire/datasource-store#20` caches one `FDBTransaction` on
the `FdbFile` and reuses it across `xRead` calls for up to four
seconds. Every read in that window shares one GRV and one snapshot.
`flush` (successful FDB commit), `fdb_close`, and any retryable
error invalidate the cached transaction. `run_txn` is untouched.
`fdb_transaction_set_option(USE_GRV_CACHE)` is not touched: every
transaction still asks the cluster for its own read version, we
just stop asking for a new one at every page read.

Files: `fdb_vfs.c:407-408` (cache fields), `fdb_vfs.c:411-459`
(`run_read_txn`), `fdb_read` swapped `run_txn(read_body, ...)` for
`run_read_txn(read_body, ..., f)`, `flush` sites and `fdb_close`
gained the destroy.

## Measurement

Local ladder against podman single-proc FDB (2 workers, batch 1000).
Pre-fix at 10k / 10k was 837 ops/s.

| rung  | ops/s | wall_s |
|-------|-------|--------|
| 5k    | 7,320 |   1.4  |
| 10k   | 3,461 |   5.8  |
| 25k   | 5,465 |   9.1  |
| 50k   | 3,106 |  32.2  |
| 100k  | timeout at 90 s |
|       |
| 10k pre-fix | 837 | |

Ratio at 10k: 4.1 times pre-fix. The 100k rung did not fit ninety
seconds on local podman FDB, which is single-share and saturated
against the operator's laptop. CI is 4-vCPU dedicated with native
FDB and is expected to carry it.

READ p50 dropped from 1,646 microseconds (pre-fix, 10k) to 1
microsecond at 5k and 2 microseconds at 25k. RMW p50 tracked the
same drop. The reduction confirms the diagnosis: pre-fix, every
page miss paid a GRV round trip; post-fix, cache-shared reads
land in microseconds.

## What this rung retracted or replaced

- `V-Sekai-fire/datasource-store#16` (dirty-buffer cap +
  `spec/CacheBackpressure.lean`). Correct model, wrong workload.
  Reverted by `V-Sekai-fire/datasource-store#19`.
- `V-Sekai-fire/datasource-store#17` (4 GiB PRAGMA cache
  workaround). Left in place; harmless. If the store adds a knob
  the roundtable exposes, this bump can be reduced back to 256 MiB.
- `V-Sekai-fire/entities-vsk-database-roundtable#9` (measure branch
  pointing at share-read-txn) landed the workflow that measured
  #20; `#11` retargeted the workflow at main/main and fixed the
  tee-masking that hid the 90 s stall on the buggy `#9` runs.
- `V-Sekai-fire/entities-vsk-database-roundtable#10` (concurrency
  groups) is unrelated to Rung 12 but landed alongside it.

## Standing record

Off-CI on 8-proc redwood, 8 workers, batch 1000: 90,391 ops/s
(unchanged from Rung 11 baseline). On-CI direct-round throughput
pending the merged-main run against the share-read-txn fix; the
merged workflow has `set -o pipefail` so the number will be
reported honestly rather than masked.
