# FDB server tuning: multi-process and storage engine

The `fdb-test` container ran a single `fdbserver` process holding every
role (coordinator, master, commit_proxy, grv_proxy, resolver, log,
storage). CPU profile in Rung-9's write-up showed the FDB C client's
network thread and every FDB role serialising through one process.

## What was tried

Both changes made in the `fdb-test` container (`weftspun-fdb` is
production and off-limits by user directive):

1. Recreated the container to publish ports 4500–4507.
2. Launched seven additional `fdbserver` instances on 4501–4507 with
   distinct datadirs and role classes: three `stateless` (proxy /
   resolver), three `log`, one `storage`.
3. `configure new single memory` then `configure ssd-redwood-1-experimental`
   with `storage_migration_type=aggressive`.

Post-migration role spread (from `status json`):

- 4500: coordinator, log, storage
- 4501: commit_proxy, resolver
- 4502: cluster_controller, commit_proxy
- 4503: master, data_distributor, ratekeeper, commit_proxy
- 4504: grv_proxy
- 4505, 4506: log (× 2 each)
- 4507: storage

Which matches the cluster's *desired* config (3 commit proxies, 1 grv
proxy, 1 resolver, 3 logs) for the first time.

## What was measured

4 workers × batch 1000 × read_depth 128, same YCSB workload F shape:

| shape                              | ops/s   | RMW p99 (ms) |
|------------------------------------|---------|--------------|
| 1-proc memory (Rung 9 baseline)    | 12,164  | 476          |
| 8-proc memory                      |  9,533  | 458          |
| 8-proc ssd-redwood-1               | **12,501** | 448      |
| 8-proc ssd-redwood-1, 8 workers    |  8,236  | 836          |

## Reading

Multi-process FDB on a single machine trades in-process function calls
for TCP-loopback hops between proxy / resolver / log / storage. On a
single-node local benchmark those hops cost more than the parallelism
gained, which is why 8-proc memory *regressed* by 22 %. Redwood recovers
the loss and adds ~2.7 % on top of the 1-proc memory baseline, because
its write path is meaningfully faster than the memory engine's
sequential WAL. The memory engine is optimised for HDD write patterns,
not modern SSDs.

At eight workers the picture doesn't improve: with the store now issuing
work through eight iceoryx2 shards, the per-shard subscriber path
(one `iox2_subscriber_receive` at a time) becomes the wall the FDB
change can no longer move.

## Standing record

**12,501 ops/s** at 4 workers × batch 1000 × read_depth 128 with 8-proc
FDB running the redwood storage engine. Rung 5, 7, 8, 9 all shipped;
Rung 6 retracted for YCSB; storage engine and role fan-out
add ~2.7 % over single-proc memory. Further honest wins want a
substrate change we don't have (weftspun-fdb is prod, off-limits) or
a workload where cross-avatar / cross-tick contention brings the
multi-proc proxies into their own. YCSB F is not that shape.

## What did not fit the docs

The docs' guidance "one fdbserver per core" is written for real
deployments where the machines carrying storage are separate from the
machines running the client. In our loopback single-machine benchmark,
the extra processes contend for the same 8 cores that the store and
the driver already use. A future measurement on two machines (one for
FDB, one for the driver+store) is the shape where multi-process would
show a bigger delta; on this box, it doesn't.
