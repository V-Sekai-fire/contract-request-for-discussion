# Rung 10 Slice 1: vendor SQLite, swap the link

`btree.c` is not reachable through Debian's `libsqlite3-0`. SQLite's
`src/btree.h` is an internal header the amalgamation collapses into a
single translation unit. Replacing btree requires building SQLite from
source that we can edit. This slice does the build-shape change with
zero behaviour change: vendor the amalgamation, swap the store's link
from system `libsqlite3` to the new `weft_sqlite3` static target, verify
the ladder still measures where it did.

## What landed

- `thirdparty/sqlite/{sqlite3.c, sqlite3.h, sqlite3ext.h}`. SQLite
  3.40.1 amalgamation from `sqlite.org`, pinned to what Debian
  bookworm-slim ships as `libsqlite3-0`. No local edits.
- `thirdparty/sqlite/CMakeLists.txt`. Defines `weft_sqlite3` as a
  static, PIC-enabled library with `SQLITE_THREADSAFE=2`,
  `SQLITE_OMIT_SHARED_CACHE`, `SQLITE_OMIT_AUTOVACUUM`,
  `SQLITE_OMIT_DEPRECATED`, `SQLITE_ENABLE_LOAD_EXTENSION` and
  `SQLITE_DEFAULT_MEMSTATUS=0`.
- Root `CMakeLists.txt`. Drops `find_path(SQLITE_INCLUDE_DIR ...)` and
  `find_library(SQLITE_LIBRARY ...)`, adds `add_subdirectory(thirdparty/
  sqlite)`, and swaps `${SQLITE_LIBRARY}` for `weft_sqlite3` on
  `weft_fdb_vfs`. The change propagates transitively; nothing else in
  the tree needed to move.

## Verification

- `ldd /tmp/store-build/store` shows **no** `libsqlite3.so` link. The
  vendored SQLite is statically embedded.
- `nm store | grep sqlite3_libversion` finds it in the binary (at
  `T sqlite3_libversion`); the symbol is provided by our copy, not the
  system's.
- `integrity ok-1.db` → `ok`.
- `prove_big_commit big-1.db 100 1024` →
  `committed 100 rows of 1024 bytes, about 0 MiB in one commit /
   read back 100 rows, 102400 bytes / integrity_check: ok`.
- YCSB `ycsb_driver 1000 10000 4 1000 1 128` on 8-proc redwood FDB:

| build           | ops/s   | READ p99 (µs) | RMW p99 (ms) |
|-----------------|---------|---------------|--------------|
| system libsqlite3 (prior) | 12,164 |     651       |     476      |
| vendored SQLite (this)   | 11,722 |     651       |     492      |

Within run-to-run substrate noise (~3.6 %). Same behaviour.

## What this slice does not do

- Does not replace `btree.c`. The full amalgamation is compiled
  as-shipped, so every btree call still walks the SQLite page tree
  down through `fdb_vfs.c`.
- Does not remove the loadable-extension form (`weft_fdb_vfs_ext`) :
  the roundtable's JDBC path still uses it and this slice preserves
  that.
- Does not delete the runtime `libsqlite3-0` from the container yet.
  The Containerfile still installs it; the store no longer needs it,
  but the Debian package trail is left in place until Slice 5 retires
  `fdb_vfs.c`.

## Next slice

Slice 2 cuts `btree.c` out of `sqlite3.c` at the amalgamation-section
markers (`/************** Begin file btree.c ***********/` …
`/************** End of btree.c ***********/`) and links
`btree-fdb/btree_fdb.c` in its place. The four-op surface stated in
`spec/BtreeReplacement.lean` and the order-preserving encoding tested
in `btree-fdb/encode_test.cc` are the load-bearing pieces; the new
work is the ~73-entry `sqlite3Btree*` shim.
