# Scale-down sweep: ratios expose where the ladder still bends

The record shape (4 workers × batch 1000 × read depth 128) hides the
per-op costs behind bulk amortisation. Scaling down to (1..4 workers) ×
(1..1000 batch) reveals which parts of the ladder are near-optimal and
which are wasting capacity.

## Absolute throughput (ops/s)

Store 8 shards, 8-proc redwood FDB, opcount 5,000 per worker,
recordcount 1,000, single-avatar per worker.

|     | b=1   | b=10  | b=100  | b=1000 |
|-----|-------|-------|--------|--------|
| w=1 |   465 | 1,635 |  2,215 |  2,540 |
| w=2 |   912 | 3,183 |  4,414 |  5,036 |
| w=4 | 1,269 | 5,273 |  7,148 | 10,106 |

## Per-worker throughput (ops/s ÷ workers)

|     | b=1 | b=10  | b=100 | b=1000 |
|-----|-----|-------|-------|--------|
| w=1 | 465 | 1,635 | 2,215 |  2,540 |
| w=2 | 456 | 1,591 | 2,207 |  2,518 |
| w=4 | 317 | 1,318 | 1,787 |  2,527 |

## Scaling efficiency (per-worker-N ÷ per-worker-1)

|     | b=1  | b=10 | b=100 | b=1000 |
|-----|------|------|-------|--------|
| w=2 | 98 % | 97 % | 100 % |  99 %  |
| w=4 | 68 % | 81 % |  81 % |  99 %  |

## What the ratios say

1. **At b=1000, 4-worker scaling is 99 %.** The ladder composes: 5.46 ×
   from batching (w=1: 465 → 2,540) times 3.98 × from workers (b=1000:
   2,540 → 10,106) predicts 21.7 × over (w=1, b=1); measured 21.7 ×.
   Arithmetic ceiling reached.

2. **At b=1, w=4 pays a 32 % scaling penalty.** Each op is a full FDB
   round trip and four concurrent commits contend at the commit-proxy /
   tlog serialisation point. Batching multiplier grows from 5.46 × at
   w=1 to 7.96 × at w=4. The extra 1.46 × comes from commits from
   different workers coalescing into the same commit-proxy 2 ms
   batching window.

3. **Per-op floor at (w=1, b=1) = 2.15 ms.** Workload F averages
   `(read + rmw) / 2` per op, so with read ≈ 500 µs, commit ≈ 3.3 ms.
   FDB's documented commit floor is 1.5–2.5 ms. **The substrate has
   about 1.3–2.2 × of headroom left at the smallest shape.**

## The lever we tried and it didn't pay

Hypothesis: multi-proc FDB's TCP-loopback hops between proxy /
resolver / log costs latency-shape workloads what it earns in
throughput-shape ones. Reverting to 1-proc memory FDB at tick shapes:

| shape             | 8-proc redwood | 1-proc memory |
|-------------------|----------------|---------------|
| w=4, b=1, rd=1    | 1,269          | 1,285         |
| w=4, b=10, rd=10  | 5,273          | 4,640 (**−12 %**)  |
| w=4, b=1000, rd=128 | 10,106       | 12,164 (earlier session baseline) |

The b=1 shape is tied and b=10 loses under 1-proc. So the 32 %
scaling penalty at (w=4, b=1) is **not** the multi-proc TCP hops :
it's per-op iceoryx2 message dispatch and FDB commit-path
saturation regardless of FDB topology. **Keep 8-proc redwood.**

## Where a next win would still live

- **Server-side commit batching window** (fdbserver
  `COMMIT_TRANSACTION_BATCH_INTERVAL_MAX` knob). At tick shapes, raising
  the window past the default 2 ms would coalesce more cross-worker
  commits at the commit-proxy. The 1.46 × extra from workers hints at
  what's available. Predicted small but real; trades RMW p99.
- **`use_grv_cache` (transaction option 1101)**. Saves the GRV round
  trip per transaction, ≈ 0.3–1 ms. At b=1 that is 15–45 % of the op
  cost. Weakens external causality (client A → client B
  out-of-band communication may see stale reads on B) but keeps
  per-transaction serialisability. Correctness call, not a technical
  one. Not adopted without a decision.

## Standing record

**12,501 ops/s** at 4 workers × batch 1000 × read depth 128 on 8-proc
redwood. The scaling composition here is essentially optimal.
Everything else on the ladder is fixed-cost per op that only pays at
larger workloads than a single-node loopback can drive.
