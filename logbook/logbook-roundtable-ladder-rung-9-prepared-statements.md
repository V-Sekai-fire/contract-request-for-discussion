# Rung 9: STORE_EXEC with prepared statements over the wire

Added a new opcode `STORE_EXEC` (id 9) whose body carries parameterised SQL
plus N binding sets. The store side keeps a per-avatar cache
`unordered_map<u64, sqlite3_stmt*>` keyed by 64-bit FNV of the SQL text,
compiles on cache miss with `sqlite3_prepare_v3(SQLITE_PREPARE_PERSISTENT)`,
and reuses on hit via `sqlite3_reset` + `sqlite3_bind_text(SQLITE_STATIC)`.
The driver's INSERT (load) and UPDATE (RMW) paths now use STORE_EXEC; reads
and DDL still take the raw-text path.

## What was measured

Linux podman, single-node FDB, four shards, 4 workers, 1 avatar per worker.
Same-session comparisons (rerun back-to-back, `weft/` cleared between).

| shape                    | Rung 8 ops/s | Rung 9 ops/s | driver ticks/s per thread |
|--------------------------|--------------|--------------|---------------------------|
| b1000 × rd=128           | 12,146       | 12,164       | 720 → 370                 |
| b100  × rd=32            | 10,096       | 10,545       | (not sampled)             |
| b10   × rd=8             |  8,099*      |  6,610       | (not sampled)             |

*Prior session at slightly different substrate load.

## What Rung 9 did and did not do

**Did**: cut driver CPU roughly in half at b1000. The driver used to build a
~2 MiB SQL string per flush (1000 UPDATEs concatenated); it now builds a
40 KiB parameterised body. The store side used to parse and plan each
statement inside `sqlite3_exec`; it now hits a cache and does `reset` + bind.

**Did not**: move throughput. At every batch size measured, the bottleneck
had already moved past both driver CPU and shard-side parse. What's left
is FoundationDB commit throughput itself: at b1000, four workers ≈ four
in-flight FDB commits × ~330 ms each ≈ 12 kops/s. The measured 12,164 is
that ceiling.

## Why the b10 number went down

Rung 9 pays a fixed protocol overhead per STORE_EXEC (~20 bytes framing +
per-set headers) that is larger than the per-op savings at very small
batches. At b10 the driver sends 10 arg sets ≈ 400 bytes, so the parse
savings are real but the extra round-trip framing on cache-cold sets
(sql_len non-zero once per avatar) plus the sample dispatch cost put us
behind the concatenated-SQL path. This is not a Rung 9 regression to
adopt permanently; the driver can keep the raw-SQL path for b<32 shapes,
or a wrapper opcode that fuses the read pipeline could re-earn the win.

## What stays

The opcode, the store-side cache, and the parameterised load and RMW
paths in `ycsb_driver`. Rung 9 is a real CPU-efficiency improvement. The
driver now has ~4 idle cores at b1000 that the b1000 shape can't currently
convert into throughput because FDB is the wall. On a substrate with more
commit parallelism (or when the workload shape is CPU-bound rather than
commit-bound), that headroom cashes out.

## What comes off the ladder as a throughput lever

The prediction that prepared statements would move ops/s at the current
shape. They didn't. Standing record on this box remains 12,146 (Rung 8)
≈ 12,164 (Rung 9). Next wall is FDB commit throughput itself. And
`weftspun-fdb` is prod, off-limits.
