# Rung 10 Slice 2f: row I/O against in-memory map; CREATE TABLE succeeds

Slice 2e had cursors and meta but no row storage; CREATE TABLE tripped
on the empty sqlite_master. This slice adds a per-Pager
`WeftDb → WeftTable[] → WeftRow[]` map, keyed by (pgnoRoot, rowid),
and wires Insert / Delete / TableMoveto / Payload / PayloadFetch /
First / Last / Next / Previous / Count against it. `CREATE TABLE`
returns rc=0. `INSERT` still fails, but for a subtler reason
(SQLite's schema-cookie / iGeneration state machine), not because
the row isn't landing.

## Landed

- `pager_fdb_stubs.inl`:
  - `WeftRow { i64 rowid; u8 *data; u32 nData; }`
  - `WeftTable { Pgno pgno; WeftRow *rows; u32 n, cap; }`
  - `WeftDb { WeftTable *tables; u32 n, cap; }` hung off `struct Pager`
- `btree_fdb_impl.inl`: 9 more real bodies, all guarded via
  `WEFT_IMPL_<name>` sentinels:
  - `weft_table_get`. Bsearch/insert into the table map
  - `weft_row_locate`. Bsearch by rowid
  - `weft_row_insert`. Sorted insert or replace
  - `sqlite3BtreeInsert`. Allocate row, memcpy payload, re-anchor cursor
  - `sqlite3BtreeDelete`. Remove current row, invalidate cursor
  - `sqlite3BtreeTableMoveto`. Bsearch by intKey, position cursor
  - `sqlite3BtreeIndexMoveto`. Stub (indexes are Slice 2h)
  - `sqlite3BtreePayload` / `PayloadChecked`. Memcpy from row's bytes
  - `sqlite3BtreePayloadFetch`. Return the pointer directly
  - `sqlite3BtreeMaxRecordSize`. Generous cap for the planner
  - `sqlite3BtreeCount`. Return `WeftTable.n`
- The empty-scan `First` / `Last` / `Next` / `Previous` from Slice 2e
  are now table-aware: they iterate the sorted row array by
  `BtCursor.ix` (a `u16` VDBE reserves for exactly this).

## Behaviour

    open (weft_fdb)                           rc=0
    PRAGMA journal_mode=MEMORY                rc=0
    PRAGMA locking_mode=EXCLUSIVE             rc=0
    SELECT * FROM sqlite_master               rc=0
    BEGIN                                     rc=0
    COMMIT                                    rc=0
    CREATE TABLE t (id INT PRIMARY KEY, v)    rc=0     ← NEW
    INSERT INTO t VALUES (1, 'hello')         rc=17 SQLITE_SCHEMA
    SELECT * FROM sqlite_master (after CREATE)rc=17
    sqlite3_close                             clean

The CREATE TABLE VDBE runs end-to-end:
- `sqlite3BtreeCreateTable` allocates pgno=2 for `t`.
- `sqlite3BtreeInsert` writes a 61-byte record into
  `sqlite_master` (pgno=1) at rowid=1. The record decodes as
  `(type='table', name='t', tbl_name='t', rootpage=2, sql='CREATE ...')`
 . Canonical SQLite serialised form.
- `sqlite3BtreeUpdateMeta(idx=1)` bumps the schema cookie 0 → 1.

## The residual SCHEMA_ERROR loop

Every subsequent `sqlite3_exec` returns rc=17 ("database schema has
changed"). Tracing shows `sqlite3BtreeFirst(pgno=1)` fires 50 times
: sqlite3_exec's retry limit. Each retry:

1. `sqlite3ResetOneSchema` bumps `pSchema->iGeneration`
2. `sqlite3InitOne` calls `First → PayloadFetch → parse row → prepare
   "CREATE TABLE ..."`. Sees the row, parses it, registers table `t`
3. Re-prepare of the user SQL captures `pOp->p3 = pSchema->schema_cookie`
   and `pOp->p4.i = pSchema->iGeneration`
4. Re-execute hits `OP_Transaction`'s check
   `iMeta!=pOp->p3 || iGeneration!=pOp->p4.i`. Still trips

Something about the cookie/generation state after reload doesn't
match what the freshly reprepared statement captured. The row
lands, but the cookie protocol between InitOne and OP_Transaction
still says "stale." Bloomberg's `sqlglue.c` handles this via
`osqlbeginTransaction` and their own generation tracking. 13,477
lines of that goes into wiring exactly these edges.

Debug will focus on the interaction between:
- `sqlite3BtreeGetMeta(BTREE_SCHEMA_VERSION, ...)` and
- `pDb->pSchema->schema_cookie` after `sqlite3InitOne` reloads.

## Line count in btree-fdb/

     600 btree_fdb_impl.inl       (39 real bodies, +9 this slice)
     519 btree_fdb_stubs.inl       (trivial stubs, +9 more guarded)
     404 pager_fdb_stubs.inl       (Pager + WeftDb + row helpers)
      10 wal_fdb_stubs.inl
   ─────
   1,533 total against Comdb2's 13,477 (~11 %)

Standing YCSB record unchanged: **12,501 ops/s** at 4w × b1000 × rd=128
on the default build.

## What Slice 2g needs

Fix the SCHEMA_ERROR loop. Two candidate fixes to investigate:

- `sqlite3BtreeCommitPhaseTwo` should mark the schema stable so
  `sqlite3ResetOneSchema` isn't re-triggered.
- `iBDataVersion` may need to change on commit; SQLite reads it as
  `sqlite3PagerDataVersion(pPager) + p->iBDataVersion` at line 78165.

Once SCHEMA_ERROR clears, the fork will run full CRUD against
the in-memory map. Slice 2h is persistence. Replace `sqlite3_free` /
`sqlite3_malloc` with `Weft.Backend` `set` / `get` under
`weft/db/<name>/T/<pgno>/<encoded_pk>` keys.
