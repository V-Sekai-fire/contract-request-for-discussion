# Rung 10 Slice 2d: SQLite opens on the fork

Slice 2c had the fork's build linking, `sqlite3BtreeOpen` allocating a
real `sqlite3_file` through the VFS, but the runtime crashed on the
first `PRAGMA`. Two changes this slice landed:

1. **`-O1` for the vendored amalgamation.** At `-O3`, GCC-14 inlined
   our `sqlite3PagerFile` / `sqlite3BtreePager` stubs, reasoned about
   fd's provenance too tightly, and eliminated `sqlite3_file_control`'s
   else branch as unreachable. The stub-shaped code fooled the
   compiler; `-O1` keeps the else branch alive.
2. **Real `sqlite3BtreePager` body.** Was a trivial stub returning 0;
   returns `p->pBt->pPager` now. Guarded in the stubs file via
   `WEFT_IMPL_sqlite3BtreePager`.

## Result

    sqlite3_open_v2(..., "weft_fdb")   → rc=0
    PRAGMA journal_mode=MEMORY         → rc=0
    PRAGMA locking_mode=EXCLUSIVE      → rc=0
    CREATE TABLE t (...)               → rc=11 (SQLITE_CORRUPT: "database disk image is malformed")
    INSERT INTO t VALUES (1, 'hello')  → rc=1  (SQLITE_ERROR: "no such table: t")
    sqlite3_close                       → clean

The fork opens a real SQLite database against the FDB VFS.
`sqlite3_file_control` dispatches correctly through the fake Pager to
the real fd, so pragmas that ride file_control (journal_mode,
locking_mode) return success.

`CREATE TABLE` reads sqlite_master to check for name conflict, and our
trivial `sqlite3BtreeFirst` / `Next` / `Payload*` stubs report "no
schema rows" without touching the store. But then the shape of the
schema-cookie / freelist counters SQLite reads back doesn't match
what it expected to write, so it declares the disk image malformed.
That's Group A + C row-I/O territory: the next slice's work.

## What's on disk

Nothing yet. The fork's `BtreeOpen` opens the file through the VFS,
which allocates FDB namespace keys under `weft/db/final.db/…`, but the
btree side never writes anything to it because Group A stubs are
trivial. `fdbcli` shows only the OPEN-time metadata rows the VFS
writes (HEAD=0, SIZE=0, FENCE, etc.). No table rows yet.

## Line count so far

    228 btree_fdb_impl.inl        (real bodies: 16 entry points)
    449 btree_fdb_stubs.inl       (trivial stubs: 79 names)
    367 pager_fdb_stubs.inl       (real Pager struct + 6 real bodies + 72 stubs)
     10 wal_fdb_stubs.inl         (Wal type tag)
   ────
   1,054 total, unchanged from Slice 2c (edits were retargeting, not new code)

Default build (WEFT_BTREE_FDB=OFF) unchanged. Standing YCSB record on
this box remains **12,501 ops/s** at 4w × b1000 × rd=128.

## What Slice 2d proved

- The excision → stubs → real bodies model actually works. Four
  turns in, `sqlite3_open` + pragma + close cycle succeeds end-to-end
  through the fork. That is the first non-linker milestone.
- The `-O1` workaround is a debt: fix it by making our stubs less
  friendly to whole-program-DCE. Cheapest fix: mark
  `sqlite3PagerFile` and `sqlite3BtreePager` as `SQLITE_NOINLINE`, or
  add an `asm volatile("")` barrier. Not urgent.

## Next slice (2e)

Row I/O. `sqlite3BtreeCreateTable`, `Cursor`, `First`, `Next`,
`Insert`, `Delete`, `Payload*`, `UpdateMeta`. Backed by the encoding
in `btree-fdb/encode.h` and reading/writing through
`sqlite3OsRead` / `sqlite3OsWrite` on the fd we hold. For now that
still goes through the SQLite page abstraction inside `fdb_vfs.c`,
because we haven't replaced the page format yet. Slice 2f would
switch to direct FDB reads through a new `Weft.Backend` C API,
skipping the VFS's PIDX/DELTA layer entirely. But that's a separate
step and its own turn.
