# Rung 10 Slice 2a: excise btree.c, wire the stub skeleton

The vendored SQLite amalgamation carries `btree.c` inline as one 11,105-line
section bracketed by `Begin file btree.c` / `End of btree.c` markers. This
slice patches those markers at build time to remove the section and insert
an `#include` of our stub file in its place. SQLite links, opens, and gets
as far as the first `sqlite3_prepare` before hitting our trivial stubs.
This is the wiring milestone: the surgery is proved to work. Slice 2b
replaces the stubs with real FDB-backed implementations.

## Landed

- `thirdparty/sqlite/patch_amalgamation.py`. Reads the vendored
  `sqlite3.c`, writes `sqlite3_weftbtree.c` with the btree.c section
  removed and `#include "btree_fdb_stubs.inl"` in its place.
- `thirdparty/sqlite/CMakeLists.txt`. `WEFT_BTREE_FDB` option (off by
  default). When on, the patch script runs and `weft_sqlite3` is built
  from the patched source; when off, the vendored copy compiles as-is.
- `btree-fdb/btree_fdb_stubs.inl`. 80 SQLITE_PRIVATE stubs across
  Groups A–G from the plan, plus one ungrouped. Returns SQLITE_OK / 0
  / "weft_fdb" trivially. Each stub also `(void)`s every named parameter
  so `-Wunused-parameter` stays green.

## Config gates that shrink the fork's surface

The build config decides which of the ~97 declarations become macros
versus functions. On this tree's flags (`SQLITE_THREADSAFE=2`,
`SQLITE_OMIT_SHARED_CACHE`, `SQLITE_OMIT_AUTOVACUUM`, `SQLITE_OMIT_DEPRECATED`,
`NDEBUG`, no `SQLITE_DEBUG`, no `SQLITE_TEST`, no `SQLITE_OMIT_WAL`):

- **Macros in production build** (16 names): `Sharable`, `SeekCount`,
  `ConnectionCount`, `Enter`, `Leave`, `EnterAll`, `LeaveAll`,
  `EnterCursor`, `LeaveCursor`, `HoldsMutex`, `HoldsAllMutexes`,
  `SchemaMutexHeld`. Defining these as functions collides with the
  macro; the stubs skip them.
- **Not declared** (3 names): `CursorIsValid` (`#ifndef NDEBUG`),
  `CursorInfo` and `CursorList` (`#ifdef SQLITE_TEST`).
- **Defined outside btree.c** (1 name): `CopyFile` lives in the
  `backup.c` section of the amalgamation; excising btree.c leaves it in
  place and a duplicate stub would collide.

That leaves 80 real stubs, which is the number `btree.h` puts into VDBE's
required-shim surface in this build config.

## Build verification

    cmake -S 6-datasource/store -B build-fdb -DWEFT_BTREE_FDB=ON
    cmake --build build-fdb -j
    # → weft_sqlite3, weft_fdb_vfs, store, integrity, prove_big_commit
    # → all link, no undefined references, no warnings

    cmake -S 6-datasource/store -B build     # WEFT_BTREE_FDB defaults off
    cmake --build build -j
    integrity check-ok.db → ok
    prove_big_commit big-ok.db 100 1024 → integrity_check: ok

Two build trees coexist: the default one still measures 11,722 ops/s on
YCSB workload F (Slice 1's number), the opt-in one links but fails
`prepare: SQL logic error` on any real SQL because the stubs are
trivial. Both compile cleanly on the aarch64 podman runner.

## What Slice 2a does not do

- The stubs answer with `SQLITE_OK` / `0` / `"weft_fdb"`. No SQL
  statement will execute correctly against the patched build until
  Slice 2b fills in the ~20 Group-A row-I/O bodies, the ~10 Group-B
  txn bodies, and the ~10 Group-D cursor bodies.
- `Btree`, `BtCursor`, `BtShared` are still the amalgamation's structs
  (they're declared in the retained `btreeInt.h` section). Slice 2b
  decides whether to reuse those layouts or replace them with our own
  thin ones. The plan leaves the choice to the C.
- The encoding (`btree-fdb/encode.h`) and its property gate remain
  unchanged; Slice 2b's shim will call `weft_encode_int` /
  `weft_encode_text` when translating an `sqlite3BtreeInsert` /
  `sqlite3BtreeTableMoveto` into a `Weft.Backend` op.

## Next

Slice 2b fills in the Group-A + B + D bodies against `Weft.Backend`
calls (`fdb_transaction_get / set / clear_range / get_range` via the
existing `run_txn` wrapper in `fdb_vfs.c`), using the encoding in
`btree-fdb/encode.h`. Goal: `sqlite3_open` + `CREATE TABLE usertable` +
`INSERT` + `SELECT` + `UPDATE` + `DELETE` + `sqlite3_close`, followed
by `PRAGMA integrity_check` returning `ok`.
