# Rung 10 Slice 2b: first real bodies, txn lifecycle

Slice 2a wired the btree.c excision and linked with trivial stubs. This
slice replaces the stubs for the txn-lifecycle group with real bodies
that allocate a Btree/BtShared, track `inTrans`, and satisfy the field
accesses `sqlite3_txn_state()` makes. Row I/O, cursor lifecycle, and
schema tables remain trivial stubs. The build links; the runtime
segfaults inside VDBE on the first prepare, because VDBE dereferences
Btree / BtShared fields our minimum initialisation does not populate.

This is the honest state of a multi-week project one turn in. It is not
a throughput win. It is scaffold.

## Landed

- `btree-fdb/btree_fdb_impl.inl`. New file. Real bodies for 15 entry
  points: sqlite3BtreeOpen, Close, BeginTrans, CommitPhaseOne,
  CommitPhaseTwo, Commit, Rollback, TxnState, GetMeta, UpdateMeta,
  Schema, SchemaLocked, GetPageSize, GetFilename, GetJournalname. Each
  sets `WEFT_IMPL_<name>` so the stubs file skips its stub. Includes a
  `WeftPager` stand-in (one `iDataVersion` field) attached to
  `BtShared.pPager` because the amalgamation reads
  `pBt->pPager->iDataVersion` in `iBDataVersion`.
- `btree-fdb/btree_fdb_stubs.inl`. 15 stubs `#ifndef`-guarded around
  the `WEFT_IMPL_<name>` sentinels. Skeleton `#include`s the impl file
  at the top of the file.

## Behaviour

    cmake -S 6-datasource/store -B build-fdb -DWEFT_BTREE_FDB=ON
    cmake --build build-fdb -j                                # links clean
    prove_big_commit smoke.db 10 100                          # → SIGSEGV
    integrity smoke.db                                        # → silent SIGSEGV

Default build (WEFT_BTREE_FDB=OFF) still passes prove_big_commit,
integrity, and YCSB workload F at 11,722 ops/s.

## What the segfault says

The crash sits inside VDBE, not the shim. VDBE reads fields of
`Btree` and `BtShared` (and follows `BtShared.pPager` into a real
Pager) that our minimum `sqlite3BtreeOpen` does not populate. The
allocation zeroes the structs, so the crash is a NULL deref inside a
BtShared/Pager field the amalgamation assumes is a real pointer.

## What Slice 2b still owes

- Populate every field on Btree, BtShared, Pager that VDBE / prepare.c /
  build.c reads directly. The list is long: pPager (real Pager, not
  our stand-in) → journalMode, pageSize, nPage, aOverflow, etc.
- Real cursor implementations. VDBE opens a cursor immediately on
  connection startup to scan `sqlite_master`.
- Row I/O. `sqlite3BtreeFirst` / `Next` / `Eof` / `Payload*` /
  `TableMoveto`. The ~20 Group-A entries the plan named.
- Schema-table encoding. `sqlite_master` has to be readable through the
  fork before any user table works.

None of this is one-turn work. Slice 2b needs its own multi-turn plan
and its own PR sequence; today it is scaffold with a linked binary that
crashes on the first prepare.

## What is honest to say

- Rung 10's Lean spec, encoding, and stub skeleton are shipped and
  proven correct on their own terms.
- The build machinery that excises 11,105 lines of upstream btree.c
  and links our replacement is proven to work.
- The txn-lifecycle group's real bodies are in place, but standing
  alone they are not enough to open a database.
- The standing YCSB record on this box remains **12,501 ops/s** at
  4 workers × batch 1000 × read_depth 128, from the default build
  (upstream btree.c through the FDB VFS).

Slice 2b will need a proper multi-turn budget. This turn advanced the
scaffold and made the next blocker visible.
