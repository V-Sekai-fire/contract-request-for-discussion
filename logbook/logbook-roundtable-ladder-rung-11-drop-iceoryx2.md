# Rung 11: drop iceoryx2, link SQLite + FDB VFS directly

Rungs 1–9 climbed inside the ycsb_driver → iceoryx2 → store-daemon
→ FDB path. Rung 10 (btree fork) revealed the daemon existed only
because SQLite handles couldn't safely be shared across processes.
Once the storage substrate *is* FDB, that concern belongs to FDB, not
to a message-passing shim. Rung 11 deletes the shim.

## What landed

Deleted files:
- `store.cpp`. The daemon
- `store_driver.cpp`. Its client
- `ycsb_driver.cpp`. The iceoryx2-mediated YCSB shim
- `fdb_vfs_ext.c`. SQLite loadable-extension form for the JDBC round
  (roundtable now measures via `ycsb_direct` instead)
- `thirdparty/harness/` (144 KiB, 18 files). Iceoryx2 dispatch table,
  C ABI, sigs, publisher/subscriber ports, all proofs of the daemon
- `Containerfile`'s iceoryx2 build stage and `/opt/iceoryx/lib`
  runtime mount

Added:
- `ycsb_direct.cpp`. Direct-linked YCSB workload F. Each worker links
  `libweft_fdb_vfs.a` and vendored SQLite, opens `sqlite3*` in-process
  against the `weft_fdb` VFS, runs prepared-statement load and run
  phases. No message dispatch, no daemon.

## Measurement (single machine, 8-proc redwood FDB, single-client-per-worker)

The old iceoryx2 record was 12,501 ops/s at 4 workers × batch 1000 ×
read depth 128 on YCSB workload F. Direct-linked variant, same
substrate:

    workers=1   38,581 ops/s
    workers=2   57,954 ops/s
    workers=4   81,868 ops/s
    workers=8   90,391 ops/s   ← new standing record

**7.2× the old record at 8 workers, 6.5× at 4 workers.** The 8-worker
regression that Rung 7 recorded (`8w × b1000 × rd=128 = 6,627 ops/s`)
was the iceoryx2 dispatch saturating. Not FDB. With the dispatch
gone, 8 workers now scales positively past 4.

## Why it wins this much

The old path per op:

    driver op → iceoryx2 loan+send → shard-thread iox2_receive
              → shard-thread SQL execute → iceoryx2 reply send
              → driver receive → next op

Each of those five stages was ~100 µs on the box. That's ~500 µs of
overhead per op that had nothing to do with SQLite or FDB. The
in-process path is:

    driver op → sqlite3_step → next op

READ p99 dropped from 664 µs (via daemon) to 3 µs (direct). That's the
measurement of everything the daemon was contributing.

## What we kept

- `weft_fdb_vfs.a`. The FDB VFS itself, unchanged; provides
  serialisability, the FENCE key, group-commit hooks.
- `fdb_vfs.c`'s `weft_txn_begin/join/commit/abort`. Rung 6 parallel
  commits, now callable directly from the app.
- All Lean 4 specs and `keys-witness/` property tests, unchanged.
- The Rung 10 fork subtree (`btree-fdb/`, `thirdparty/sqlite/`),
  behind `WEFT_BTREE_FDB=ON`, ready for when Slice 2h wires
  persistence.

## Reduced surface

    before Rung 11:  store.cpp + store_driver.cpp + ycsb_driver.cpp
                     + thirdparty/harness/ (18 files)   ≈ 5,000 lines
    after Rung 11:   ycsb_direct.cpp                    ≈   200 lines

`Containerfile` drops one whole build stage (the Rust toolchain that
built iceoryx2) and one runtime library mount. Deployment simplified
by exactly one thing.

## What Rung 11 does not do

- The Rung 10 fork (btree-fdb) still holds rows in memory. Slice 2h
  persists them under `weft/db/<name>/T/<pgno>/<encoded_pk>` FDB
  keys. That's the *next* throughput lever. The fork replaces
  SQLite's page abstraction, which is why the plan predicted
  15–25 kops/s from Rung 10 alone. Combined with Rung 11's direct
  linking, we're at 90k already; Rung 10 fully wired could push
  further.
- `ycsb_direct` measures on the *default* build (`WEFT_BTREE_FDB=OFF`),
  running upstream SQLite btree over the FDB VFS. That's the honest
  baseline for the fork to beat once Slice 2h persists.

## Standing record

**90,391 ops/s at 8 workers × batch 1000, direct-linked, YCSB
workload F, 8-proc redwood FDB, single machine.** Previous record
was 12,501 (iceoryx2 path, same substrate). Rung 11's win is
essentially all IPC removal.

## Postgres comparison

Roundtable's Postgres reference was 11,845 ops/s loopback. Our
direct-linked store is now **7.6× Postgres** on the same box. That
answers the original roundtable question: the SQLite-on-FDB
architecture, at 90k ops/s workload F, exceeds Postgres by a wide
margin. Not because FDB is faster than a single-node RDBMS at
individual commits (it isn't), but because the daemon was the wall
and removing it recovers the substrate's real throughput.
