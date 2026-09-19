# Rung 6 (CockroachDB Parallel Commits): retracted for YCSB workload F

Rung 6 groups M avatars under one `STORE_TXN_BEGIN` / N × `STORE_TXN_JOIN`
/ per-avatar `STORE_COMMIT` (stage) / `STORE_TXN_COMMIT` (atomic finalise),
per `spec/ParallelCommit.lean`. The Lean proof stands: a merged commit's
read set is the union of the parts and any conflict aborts the whole
group. What retracts is the *throughput* prediction. It is not a win on
this workload.

## What was measured

Store is a single-node FDB-backed VFS, four shards, Linux podman.
`ycsb_driver` writes YCSB workload F (50% READ, 50% RMW, `recordcount=1000`,
`opcount=10000`). `workers` is the Rung 7 fanout; `avatars_per_worker`
(apw) is Rung 6. The whole `weft` keyspace is cleared between runs.

| shape                    | ops/s   | READ p99 (µs) | RMW p99 (ms) |
|--------------------------|---------|---------------|--------------|
| 4w × 1apw × b100 (R7)    | 10,096  | 737           | 51           |
| 4w × 4apw × b100 (R6+R7) | 11,052  | 651           | 61           |
| 4w × 1apw × b10  (R7)    |  8,099  | (prior)       | 24           |
| 4w × 4apw × b10  (R6+R7) |  1,710  | 542           | 89           |
| 1w × 4apw × b10  (R6)    |  1,032  | 492           | 32           |

At batch 100, Rung 6 adds 9.5% throughput and 20% tail. At batch 10 it
loses 79% throughput and quadruples the RMW tail. The three extra round
trips per flush (BEGIN, JOIN × M, TXN_COMMIT) amortise only when the
batch is large. And at large batch, the plain Rung 7 path is already
near the local FDB commit ceiling, so the amortised win is small.

## Why the prediction was wrong

The prior guess was that N per-avatar commits per cycle would collapse
into one merged commit and drop `commit_cost / N`. It does. The FDB
commits do collapse. But every parallel-commit cycle sends three protocol
messages the plain Rung 7 path does not send at all (BEGIN, one JOIN per
avatar, TXN_COMMIT), and the RMW batch has to be held until every avatar
in the group flushes. On this workload the second cost is larger than the
first, and the tail measurement is what carries it.

## What stays

The Lean proof, the opcodes on the store, and the driver mode. Rung 6 is
the correctness lever for cross-avatar atomicity. A tick that must
either update every avatar it names or none of them. That is a shape
YCSB workload F does not have, so YCSB does not measure the property
Rung 6 pays for. An MMO tick that names multiple avatars per commit
is the workload where Rung 6 pays; that measurement is separate.

## What comes off the ladder

The line in the plan predicting Rung 6 would push YCSB throughput toward 14,711 is withdrawn:
the measurement does not reach it. The record on this box, on this workload, remains
Rung 5+7 (4 workers × batch 1000) at 14,711 ops/s.
