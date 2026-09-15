# Rung 10 Slice 2g: cookie fix. Full CRUD runs on the fork

Slice 2f had the schema record landing in our in-memory row map, but
every statement after `CREATE TABLE` returned `SQLITE_SCHEMA`. Three
parallel Explore agents traced the exact SQLite invariant we were
violating. The fix is five lines. Full CRUD now runs end-to-end
through the fork.

## The bug and the fix

`sqlite3BtreeBeginTrans(Btree*, wrflag, int *pSchemaVersion)` is
called by every `OP_Transaction`. SQLite uses `*pSchemaVersion` as
`iMeta`. The "current on-disk schema cookie". And compares it
against the cookie captured when the statement was prepared. Our
Slice 2b impl returned `0` unconditionally.

Under `WEFT_BTREE_FDB=ON`:

- `CREATE TABLE` bumps `meta[1]` (schema cookie) from 0 to 1 via
  `UpdateMeta`, and mirrors the value into
  `pDb->pSchema->schema_cookie` via `OP_SetCookie`
  (`sqlite3.c:93745`).
- Next statement's prepare captures `p3 = pSchema->schema_cookie = 1`.
- Execution calls `BeginTrans` → our impl returned `iMeta = 0`.
- `iMeta != p3` → `SQLITE_SCHEMA`. Reset gate at `sqlite3.c:93669`
  finds `schema_cookie != iMeta`, tears down the in-memory schema,
  `sqlite3Reprepare` reloads via `InitOne`, re-prepares (with
  `p3 = 1` again), re-executes → `BeginTrans` still returns 0 →
  same mismatch. Loop runs 50 times (`SQLITE_MAX_SCHEMA_RETRY`,
  `sqlite3.c:22335`), then gives up.

The fix is to return the value that already lives in `meta[1]`:

```c
SQLITE_PRIVATE int sqlite3BtreeBeginTrans(Btree *p, int wrflag, int *pSchemaVersion){
    if (pSchemaVersion) {
        *pSchemaVersion = (p && p->pBt && p->pBt->pPager)
                          ? (int)p->pBt->pPager->meta[1]
                          : 0;
    }
    p->inTrans = (u8)(wrflag ? TRANS_WRITE : TRANS_READ);
    return SQLITE_OK;
}
```

Comdb2 confirmed by inversion: their `sqlite3BtreeGetMeta` returns
`0` unconditionally, `UpdateMeta` is a logging no-op, and their
custom `Btree` struct carries no `iSchemaVersion`. They avoid the
cookie loop entirely by intercepting all DDL *before* it reaches the
btree layer (schema-change on `osqlcomm.c:7284`). Our path preserves
SQLite's cookie protocol; we just needed the one out-parameter wired
to the storage we already had.

## Behaviour after the fix

    open (weft_fdb)                       rc=0
    PRAGMA journal_mode=MEMORY            rc=0
    PRAGMA locking_mode=EXCLUSIVE         rc=0
    CREATE TABLE t (id INTEGER PK, v)     rc=0
    INSERT INTO t VALUES (1, 'hello')     rc=0    ← NEW
    INSERT INTO t VALUES (2, 'world')     rc=0    ← NEW
    INSERT INTO t VALUES (3, 'goodbye')   rc=0    ← NEW
    SELECT id, v FROM t ORDER BY id       rc=0, 3 rows
      id=1 v=hello / id=2 v=world / id=3 v=goodbye
    SELECT * FROM sqlite_master           rc=0, 1 row
      type=table name=t tbl_name=t rootpage=2
      sql=CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)
    UPDATE t SET v='updated' WHERE id=2   rc=0
    SELECT id, v FROM t ORDER BY id       id=1/hello id=2/updated id=3/goodbye
    DELETE FROM t WHERE id=1              rc=0
    SELECT id, v FROM t ORDER BY id       id=2/updated id=3/goodbye
    sqlite3_close                          clean

Everything round-trips: keys, values, ordering, sqlite_master
metadata. `UPDATE` finds the right row via `TableMoveto` and replaces
via `Insert`. `DELETE` shifts the sorted array. `ORDER BY` walks
`First` → `Next` in sorted order.

## Measurement (in-process, single client)

Not comparable to YCSB's iceoryx2-mediated multi-worker shape. This
is a direct-linked benchmark for shape verification, not a throughput
claim.

    /tmp/mini_ycsb_fdb bench.db 1000    (fork, in-memory map)
      INSERT: 2,255,010 ops/s
      READ:   3,544,026 ops/s

    /tmp/mini_ycsb_default def.db 1000  (default, real FDB via VFS)
      INSERT:   216,768 ops/s
      READ:  1,455,257 ops/s

The fork's raw numbers are "no persistence yet." Slice 2h wires the
in-memory map to `Weft.Backend` under `weft/db/<name>/T/<pgno>/…`
keys, which is where the honest comparison lives. The fork's read
number (3.5 M / s) is what direct-lookup-in-a-sorted-array plus
SQLite's VDBE overhead costs, without any store round trip; the
default's 1.5 M reads/s eats one page walk per read against fdb_vfs's
FDB VFS (cache-warm).

## Standing state

- Default build (`WEFT_BTREE_FDB=OFF`): **12,501 ops/s** on YCSB
  workload F, `prove_big_commit` and `integrity` still return `ok`.
- Fork build: full CRUD (CREATE/INSERT/SELECT/UPDATE/DELETE) all
  succeed. Not persisted.
- Lines in `btree-fdb/`: 1,538 (Slice 2f + 5-line cookie fix), against
  Comdb2's 13,477 (~11 %).

## What Slice 2g does not do

- No FDB persistence. Everything survives inside one process, then
  dies on `sqlite3_close`. That is Slice 2h. Replace
  `sqlite3_malloc`/`sqlite3_free` in `weft_row_insert` with
  `set`/`clear_range` on the FDB txn under
  `weft/db/<name>/T/<pgno>/<encoded_pk>` where `encoded_pk` uses
  `btree-fdb/encode.h`.
- No indexes. `sqlite3BtreeIndexMoveto` still stubs. Slice 2i.
- `sqlite3BtreeCommitPhaseOne`/`Two` still no-ops. Slice 2h routes
  them through the FDB commit protocol.

## Next slice

Slice 2h: persistence. Once each `WeftRow` is a
`(pgno_root, encoded_pk) → payload` pair in FDB, the fork will
survive `sqlite3_close` + reopen. Then the YCSB shim can run against
it and we get the first fair number since Rung 10 started.
