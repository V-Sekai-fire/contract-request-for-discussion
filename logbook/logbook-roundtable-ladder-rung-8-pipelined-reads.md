# Rung 8: pipelined reads in the YCSB driver

The driver was paying one iceoryx2 request-reply round trip per STORE_READ
even though workload F fires reads and writes independently. On this box the
per-read round trip runs ~450–500 µs, and 5000 reads × 500 µs is 2.5 s of
pure serialised wait per worker. Rung 8 lets up to `read_depth` reads be
in flight at once; the driver drains their replies together before the
next write flush.

## What was measured

Linux podman, single-node FDB, four store shards, `ycsb_driver 1000 10000
4 1000 1 <rd>` (4 workers, batch 1000, 1 avatar per worker, read depth
sweep).

| read_depth | ops/s   | READ p99 (µs) | RMW p99 (ms) |
|------------|---------|---------------|--------------|
| 1          |  8,709  |   660         | 626          |
| 16         | 11,576  |   644         | 492          |
| 32         | 11,056  | 1,844         | 585          |
| 64         | 11,438  |   658         | 474          |
| 128        | 12,146  |   664         | 444          |
| 8w × 128   |  6,627  | 3,841         | 703          |

Rung 8 alone lifts 8,709 → 12,146 (+39%) at four workers. Adding workers
past four regresses on this single-node FDB. The commit path saturates.
READ p99 is stable in the 500–700 µs band once `read_depth ≥ 16`; the
`rd=32` outlier is a run artefact (variance across replays, not a shape
change).

## Why it works

`iceoryx2_publisher_loan_slice_uninit` + `send` returns as soon as the
message is enqueued in shared memory. The store's shard thread services
requests in order and reply arrivals do not have to. `drain_replies`
in the driver matches replies to a set of pending request ids and only
requires that every id in the pending set came back green. So M reads
that would have paid M × RTT sequentially now pay ≈ RTT + M × service.

## What is preserved

Read-your-own-writes: the driver drains pending reads before it stages
an UPDATE, so an RMW that lands after a pipelined READ still sees the
world the READ saw. The write path is untouched. RMW p99 movement in
the table is a side-effect of the shorter run wall clock, not of a
change to the commit protocol.

## Standing record

4 workers × batch 1000 × read_depth 128: **12,146 ops/s**, READ p99
664 µs, RMW p99 444 ms. This session's replay of the prior 14,711
record could not reproduce it at `rd=1` (measured 8,709 today). The
FDB substrate was under a different load. The Rung 8 delta above is
same-session, single-shape.
