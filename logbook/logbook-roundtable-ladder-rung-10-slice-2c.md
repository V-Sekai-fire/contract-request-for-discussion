# Rung 10 Slice 2c: excise pager.c + wal.c, real Pager struct

Slice 2a excised btree.c. Slice 2b added real bodies for the btree
txn-lifecycle group. That surfaced a crash inside `sqlite3_file_control`
because it walks through `Btree → BtShared → Pager` and calls
`sqlite3PagerFile()`, which our stubs returned NULL for. That called
into `sqlite3OsFileControl(NULL, ...)` and dereferenced the NULL
`sqlite3_io_methods` table.

This slice makes two more amalgamation sections opt-out and defines a
real (small) `struct Pager`. The build still doesn't run SQL, but the
crash surface is one layer smaller.

## Landed

- `patch_amalgamation.py`. Now excises three sections: `btree.c`,
  `pager.c`, and `wal.c`. wal.c is dragged along because its
  `typedef struct Wal Wal` sat inside pager.c; excising pager.c
  removed the typedef and wal.c stopped compiling.
- `btree-fdb/pager_fdb_stubs.inl`. 72 stubs for the pager entry
  points, plus a real `struct Pager` layout carrying just what the
  amalgamation reads through the accessor API:
  `sqlite3_vfs *pVfs; sqlite3_file *fd; u32 iDataVersion; u8 readOnly;
   u8 memDb; char zFilename[…]`. Real bodies for
  `sqlite3PagerFile`, `PagerVfs`, `PagerDataVersion`, `PagerFilename`,
  `PagerIsMemdb`, `PagerIsreadonly`. Also
  `sqlite3_database_file_object` (public API defined in pager.c,
  referenced from `sqlite3_api_routines`).
- `btree-fdb/wal_fdb_stubs.inl`. One-line file. The single Wal
  function used outside wal.c (`sqlite3WalDefaultHook`) is actually
  defined in main.c further down the amalgamation, so this file only
  needs to provide `struct Wal { int _unused; }` as a stand-in for
  forward decls.
- `btree-fdb/btree_fdb_impl.inl`. `sqlite3BtreeOpen` now allocates a
  `sqlite3_file` sized for the VFS, calls `sqlite3OsOpen` through the
  passed-in `pVfs` (which is the FDB VFS from `fdb_vfs.c`), and stores
  the handle on `pBt->pPager->fd`. `sqlite3BtreeClose` calls
  `sqlite3OsClose` and frees. This is the first place the fork
  actually talks to the real store.

## Behaviour

    cmake -DWEFT_BTREE_FDB=ON -S 6-datasource/store -B build-fdb
    cmake --build build-fdb -j       # all targets link, no warnings
    prove_big_commit smoke.db 10 100  # SIGSEGV inside VDBE (different crash from Slice 2b)

    cmake -S 6-datasource/store -B build     # default unchanged
    prove_big_commit ok.db 10 100 → integrity_check: ok

The crash moves from `sqlite3_file_control → sqlite3PagerFile` (fixed
here) to a later dereference downstream. Each turn peels one more
onion layer.

## Line count so far

    228 btree_fdb_impl.inl        (real bodies, 15 entry points)
    449 btree_fdb_stubs.inl       (trivial stubs for 80 btree names)
    367 pager_fdb_stubs.inl       (trivial + 6 real stubs for 72 pager names)
     10 wal_fdb_stubs.inl         (Wal type tag)
   ────
   1,054 total in btree-fdb/

Against ~23,000 lines of upstream btree.c + pager.c + wal.c
replaced. The rate says something honest about the scope: three turns
in, 1 k lines out of what is going to be tens of thousands before
sqlite3_open succeeds on an empty database.

## What Slice 2c doesn't do

- No row I/O. `sqlite3BtreeInsert`, `Delete`, `First`, `Next`,
  `TableMoveto`, `IndexMoveto`, `Payload*` still return SQLITE_OK
  trivially. VDBE will keep crashing when it dereferences results
  it expects from them.
- No cursor state. `sqlite3BtreeCursor` returns SQLITE_OK but doesn't
  populate the `BtCursor`. First page-cache access blows up.
- No schema tables. `sqlite_master` reads still don't work.

Default build (`WEFT_BTREE_FDB=OFF`) remains 12,501 ops/s on YCSB
workload F. This slice made no throughput change. Path C keeps its
weeks-to-months estimate.
