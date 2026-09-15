# Rung 10 Slice 2e: cursor lifecycle, meta, CreateTable; SELECT and BEGIN/COMMIT run

Slice 2d had the fork opening a database and answering pragmas. This
slice implements the empty-scan cursor lifecycle, real `GetMeta` /
`UpdateMeta` against the Pager's meta array, and a monotonic
`sqlite3BtreeCreateTable`. `SELECT * FROM sqlite_master`, `BEGIN`, and
`COMMIT` now all return `rc=0`. `CREATE TABLE` still returns
`SQLITE_CORRUPT` because `sqlite3BtreeInsert` is a trivial stub, so
`sqlite_master` never actually gains a row and VDBE's read-back finds
the disk state doesn't match its write.

## What we studied

Bloomberg's Comdb2 (github.com/bloomberg/comdb2) is the reference
implementation of "replace SQLite btree wholesale." Their
`db/sqlglue.c` is **13,477 lines** and defines 60 `sqlite3Btree*`
entry points against their BerkeleyDB-fork backend. Key observations:

- They **redefine** `Btree`, `BtShared`, `BtCursor` completely. Fields
  like `Btree.zFilename`, `Btree.btreeid`, `Btree.is_temporary`,
  `BtCursor.thd`, `BtCursor.range`, `BtCursor.cursor_move` (a function
  pointer) have nothing in common with stock SQLite's page-cache
  layout. VDBE still reads `Btree.db`, `Btree.pBt`, `Btree.inTrans`;
  everything else is theirs.
- They dispatch cursor operations via a **per-cursor function pointer**
  `cursor_move(cur, pRes, direction)`. Different backends (main table,
  index, temp table, remote fdb) plug in their own `cursor_move`.
- Their `sqlite3BtreeOpen` special-cases `zFilename == "db"` (their
  main database), `""` or `":memory:"` (temp), and any other string
  (remote federated database).

The size confirms the plan's estimate. A minimum-viable replacement
that actually runs CREATE TABLE + INSERT + SELECT wants thousands of
lines of C, not hundreds.

## What landed this slice

- `pager_fdb_stubs.inl`: `struct Pager` grew `meta[16]` and `nextRoot`.
  These carry the schema cookie / file format / text encoding array
  and the root-page allocator between `sqlite3BtreeCreateTable` and
  subsequent cursor opens.
- `btree_fdb_impl.inl`: 14 more real entry points, guarded via the
  `WEFT_IMPL_<name>` sentinel:
  - `sqlite3BtreeGetMeta` / `UpdateMeta`. Read/write `pPager->meta[idx]`
  - `sqlite3BtreeCreateTable`. Hand out `pPager->nextRoot++`
  - `sqlite3BtreeLastPage`. Report the largest allocated pgno
  - `sqlite3BtreeIntegrityCheck`. Return "ok" (0 errors)
  - `sqlite3BtreeCursorSize`. Sizeof(BtCursor)
  - `sqlite3BtreeCursorZero`. Memset zero
  - `sqlite3BtreeCursor`. Populate `pBtree`, `pBt`, `pgnoRoot`,
    `pKeyInfo`, `eState = CURSOR_INVALID`, write-flag
  - `sqlite3BtreeCloseCursor`. No-op
  - `sqlite3BtreeFirst` / `Last`. `*pRes = 1` (past end)
  - `sqlite3BtreeNext` / `Previous`. Return `SQLITE_DONE`
  - `sqlite3BtreeEof`. Return 1 (always at end while every table
    is empty)
  - `sqlite3BtreeIntegerKey`. Return 0
  - `sqlite3BtreePayloadSize`. Return 0

## Behaviour

    open (weft_fdb VFS)         rc=0
    PRAGMA journal_mode=MEMORY  rc=0
    PRAGMA locking_mode=EXC.    rc=0
    SELECT * FROM sqlite_master rc=0 ← NEW: read side works
    BEGIN                       rc=0 ← NEW: txn open
    COMMIT                      rc=0 ← NEW: txn close
    CREATE TABLE t (...)        rc=11 (needs Insert)
    sqlite3_close               clean

VDBE's read cursor over the (empty) `sqlite_master` returns zero rows
without touching the store, so `SELECT *` from it succeeds. `BEGIN` /
`COMMIT` cycle through `sqlite3BtreeBeginTrans` (write) →
`CommitPhaseOne` → `CommitPhaseTwo` on our impl, which just tracks
`inTrans` state. Neither talks to FDB yet, but neither crashes.

## What Slice 2e does not do

- `sqlite3BtreeInsert` is still a trivial stub. VDBE's `OP_Insert` on
  `sqlite_master` "succeeds" (SQLITE_OK) but nothing is written, so a
  subsequent verify or scan finds the schema-cookie / row-count
  mismatch and raises SQLITE_CORRUPT.
- No Rung 10 code touches FDB yet. `weft/db/…/HEADER`,
  `weft/db/…/T/<pgno>/<key>`. All just plans.

## Line count in btree-fdb/

     376 btree_fdb_impl.inl        (real bodies for 30 entry points)
     501 btree_fdb_stubs.inl       (trivial stubs, 29 more guarded)
     372 pager_fdb_stubs.inl       (real Pager struct, 6 real bodies)
      10 wal_fdb_stubs.inl
   ─────
   1,259 total in btree-fdb/

Against Comdb2's 13,477 lines of sqlglue.c that does row I/O for real,
that's <10 %. Real progress, honestly measured.

## Standing YCSB record

Unchanged: **12,501 ops/s** at 4w × b1000 × rd=128 on the default
build. The fork build still runs zero SQL statements that touch data
correctly.

## Slice 2f (next)

`sqlite3BtreeInsert` + backing storage. The realistic minimum:
per-cursor in-memory row map, keyed by rowid, insertable via
`OP_Insert` and readable via `OP_Column`. Persistence to FDB is Slice
2g. Between here and CREATE TABLE returning `ok`:

- `sqlite3BtreeInsert(cur, payload, flags, seekResult)`. Copy the
  payload into a per-Btree row map indexed by (pgnoRoot, rowid)
- `sqlite3BtreeTableMoveto(cur, iKey, bias, pRes)`. Look up rowid in
  the map, position cursor
- `sqlite3BtreePayload(cur, off, amt, buf)`. Copy from the cursor's
  current row into `buf`
- `sqlite3BtreePayloadFetch(cur, *pAmt)`. Return pointer directly
- `sqlite3BtreeFirst` / `Next`. Actually iterate the map when the
  table is non-empty

Once that's in place, CREATE TABLE writes a row to sqlite_master,
the schema cookie gets bumped, and the fork can echo back its own
schema. That's the milestone before Slice 2g (persistence).
