# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2196. `mix rfd.render` renders rfd/2196-huggingface-dataset-viewer-rules/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2196 do
  use RFD.DSL

  rfd 2196, "HuggingFace dataset viewer rules" do
    state :discussion

    feature "authoring rules for HuggingFace dataset repos so the viewer renders"

    scope "any dataset published under `huggingface.co/datasets/chibifire/*`"

    decision ~S"""
    Publish HuggingFace datasets as zstd-compressed parquet shards under
    `data/`, one wide denormalized row per logical example, with row
    groups <= 300 MB and images embedded as `struct<bytes:binary, path:string>`.
    Skip ETNF/6NF normalization for anything destined for HF. Push with
    LFS + `hf_transfer`, not xet, whose finalize call times out on multi-GB
    commits.

    The viewer's contract is enforced silently by an auto-indexer that
    either succeeds or falls back to a "Preview" badge. The five rules and
    the errors each surfaces are in `DETAILS.md`, one section per rule.
    """

    problem ~S"""
    Three rebuilds on 2026-09-03 (`chibifire/editreward-bench`,
    `chibifire/editscore-rl-train`, `chibifire/editscore-reward-train`)
    each failed a different silent gate: too-big `.arrow` shards
    crashed the auto-viewer, xet finalize stalled at 6 KB/s and timed out
    twice, and one dataset silently dropped every 2-image row because
    shared image paths collided. Landing a dataset that renders needs
    each of the five rules matched at author time, not fixed after the
    push has happened.
    """

    related ~S"""
    Companion skills `hf-datasets-no-etnf`, `hf-parquet-image-column`,
    `hf-upload-large`, `hf-download-streaming` are the single-page how-to
    per rule. RFD 2183 (OmniGen layer decomp) and RFD 2193 (editscore
    reproducibility bar) both consume datasets published under these rules.
    """

    details_title "HuggingFace dataset viewer rules"

    details "The viewer's contract, verbatim from what it enforces", ~S"""
    | Rule | What breaks if you skip it | Error surface |
    |---|---|---|
    | Row group ≤ 300 MB | Scan limit exceeded | `Parquet error: Scan size limit exceeded: attempted to read <N> bytes, limit is 300000000 bytes` |
    | One row shape per split | Viewer picks arbitrary schema | Missing columns, silent NULLs |
    | Image column = `struct<bytes:binary, path:string>` | No thumbnails | Column shows as a struct blob |
    | Shards under `data/` with `train-XXXXX-of-YYYYY.parquet` | Auto-indexer skips them | "Preview" badge, no viewer |
    | Whole-commit under HF's job limits | Auto-convert job dies | `JobManagerCrashedError` |
    | LFS-backed for >10 GB pushes | Xet finalize times out | `RuntimeError: Internal error: timed out reading request body` |
    """

    details "Rule 1: one wide row per example (denormalize)", ~S"""
    The HF viewer paginates one wide table per split. Split into satellite
    tables (Hermes / ETNF / 6NF style) and the viewer's `train[0..N]`
    browsing collapses. Rules:

    - One row per logical example. NULLs are fine.
    - Nested lists and structs are fine (multiple images per row,
      conversation turns), one row per example still.
    - Do NOT emit `entity`, `entity_score`, `entity_conversation` as
      separate parquet files thinking the viewer will join them.

    Companion skill: `hf-datasets-no-etnf`.
    """

    details "Rule 2: row groups ≤ 300 MB", ~S"""
    The viewer scans one row group at a time when the reader requests a
    page. Above 300 MB it hard-fails. With images embedded (~1 MB each), a
    1000-row shard is one 1 GB row group by pyarrow default, always
    oversized.

    Write with:

    ```python
    pq.write_table(tbl, path,
                   compression="zstd", compression_level=9,
                   row_group_size=100)   # 100 rows × ~1 MB = ~100 MB
    ```

    `row_group_size` is the maximum number of rows per group. Set it so
    `rows_per_group × avg_row_bytes < 200 MB` (30 % safety margin).

    For an already-published shard, rewrite in place, no re-extraction
    needed:

    ```python
    tbl = pq.read_table(path)
    pq.write_table(tbl, path_tmp, compression="zstd",
                   compression_level=9, row_group_size=100)
    path_tmp.replace(path)
    ```
    """

    details "Rule 3: shards ~500 MB, named `data/train-XXXXX-of-YYYYY.parquet`", ~S"""
    The auto-indexer scans `data/` for files matching that name pattern and
    groups them into splits. Bigger shards (up to ~1 GB) work but slow the
    viewer's first paint. Aim for ~500 MB for image-embedded data.

    Layout examples:
    ```
    data/train-00000-of-00110.parquet     # single split
    data/train-...  data/validation-...   # multiple splits, same config
    default/train-... other/train-...     # multiple configs (put configs at top)
    ```
    """

    details "Rule 4: image column = `struct<bytes:binary, path:string>`", ~S"""
    Exact Arrow type:

    ```python
    import pyarrow as pa
    image_type = pa.struct([("bytes", pa.binary()), ("path", pa.string())])
    # single image per row
    schema = pa.schema([..., ("image",  image_type)])
    # multiple images per row (viewer renders a gallery)
    schema = pa.schema([..., ("images", pa.list_(image_type))])
    ```

    Row shape:
    ```python
    {"bytes": <raw png/jpg bytes>, "path": "images/whatever.png"}
    ```

    What does NOT work:
    - `pa.binary()` alone (no thumbnail rendering)
    - `{"path": "images/x.png"}` referencing a file elsewhere in the repo
    - gzipping/zstd-ing the image bytes yourself (parquet's zstd handles it)
    """

    details "Rule 5: LFS + hf_transfer for large pushes", ~S"""
    `huggingface_hub`'s default xet path stalls on multi-GB commits: the
    CDN endpoint sits ESTABLISHED but transmits nothing, then the client
    raises `RuntimeError: Internal error: timed out reading request body`
    on the finalize call. Observed at 94 GB / 110 shards. Multiple retries
    did not help; batching into 15-file commits did not help.

    Reliable recipe:

    ```sh
    pip install hf_transfer
    HF_HUB_DISABLE_XET=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    hf upload-large-folder \
      --repo-type dataset \
      REPO_ID LOCAL_DIR \
      --num-workers 8
    ```

    Notes:
    - `upload-large-folder` doesn't accept `--path-in-repo`. Structure
      `LOCAL_DIR` so its tree already matches the repo (put parquet under
      `LOCAL_DIR/data/`) and pass `LOCAL_DIR` itself.
    - Symlinks are not followed, move or copy real files in.
    - Per-file resume state is in `LOCAL_DIR/.cache/huggingface/`. An
      interrupted run resumes without re-hashing.
    - Do NOT run two `upload-large-folder` processes against the same
      `LOCAL_DIR`.
    - Deletes and small commits work fine over the standard
      `HfApi().create_commit` path; only large adds need the LFS+hf_transfer
      route.

    Companion skill: `hf-upload-large`.
    """

    details "Streaming download without doubling disk", ~S"""
    `hf_hub_download(..., local_dir=…)` and `hf download --local-dir` write
    the file to BOTH `~/.cache/huggingface/hub/…/blobs/` AND the requested
    `local_dir` (on macOS the intended hardlink often becomes a copy). Cost
    observed: 86 GB target dir → 170 GB actual disk.

    For one-shot streaming pipelines, bypass the cache with direct HTTPS:

    ```python
    import os, requests
    from huggingface_hub import HfApi
    TOKEN = HfApi().token or os.environ["HF_TOKEN"]
    S = requests.Session()
    S.headers["Authorization"] = f"Bearer {TOKEN}"

    url = f"https://huggingface.co/datasets/{REPO}/resolve/main/{name}"
    with S.get(url, stream=True) as r:
        r.raise_for_status()
        with open(local_path, "wb") as f:
            for chunk in r.iter_content(1 << 22):
                f.write(chunk)
    # process...
    local_path.unlink()
    ```

    For repeated reads, let the cache do its job, the doubling pays for
    retry and dedup.

    Companion skill: `hf-download-streaming`.
    """

    details "Pitfall: shared images across rows", ~S"""
    If your metadata references the same image path from multiple rows
    (observed in `chibifire/editscore-reward-train`: `images/0_0.png`
    referenced by 7 different rows), a naive `img2row: dict[str, int]` maps
    each path to only the LAST row that claimed it. When the tar stream
    delivers that image, all other claiming rows are orphaned and dropped
    silently at the end.

    Fix: `img2rows: dict[str, list[int]]` with `defaultdict(list)`, and on
    each tar member deliver the bytes to every interested row. Bytes are
    shared by reference, no memory blowup.
    """

    details "Pitfall: auto-viewer job crash on legacy `.arrow` shards", ~S"""
    A dataset saved with `datasets.save_to_disk` publishes as `.arrow`
    shards plus `dataset_info.json` / `state.json`. HF tries to
    auto-convert those to parquet in a job that has resource limits, it
    died with `JobManagerCrashedError` on the ~5 GB `chibifire/editreward-bench`
    input, leaving the viewer stuck as "Preview". Fix: convert to parquet
    yourself, push under `data/`, and delete the `.arrow` shards and
    `dataset_info.json` / `state.json` in the same commit.
    """

    details "Rule 6: `dataset_info.features` must match the on-disk Arrow shape", ~S"""
    An earlier draft of this document listed "explicit `datasets.Features`
    definition" as a non-goal, on the argument that an unambiguous Arrow
    schema was enough. Observed 2026-09-03 on
    `chibifire/zenodo-second-hand-fashion-v3`: on-disk parquet held
    `list<struct<slot, damage, damage_image, damage_location>>` (list of
    struct); the README's `dataset_info.features` block declared

       , name: damage
          sequence:
           , name: slot ...

    which HF-datasets' YAML loader reads as `Sequence(dict(...))`, and
    that translates to `struct<slot: list, damage: list, ...>` (**struct
    of lists**) in Arrow, the historical tfds convention. The viewer
    tried to cast on-disk list-of-struct to declared struct-of-lists and
    died with `UnexpectedError` on that split, viewer red.

    The two Features shapes:

    | YAML | datasets class | Arrow shape |
    |---|---|---|
    | `sequence: {...}` | `Sequence(dict)` | `struct<field: list<T>>` (struct of lists) |
    | `list: [{...}]`   | `List(dict)`     | `list<struct<field: T>>` (list of struct) |

    For a single-typed sequence (`sequence: string`) both YAML keywords
    land at `list<T>` and the distinction does not matter. For a sequence
    of records the distinction is the whole rule: pick the keyword whose
    Arrow shape matches what you actually wrote, or the auto-cast fails.

    The fix is one YAML character (`sequence:` -> `list:`) or a parquet
    rewrite that flips the shape; the character fix is trivial and
    correct-by-construction when the parquet was already list-of-struct.
    """

    details "Non-goals for this RFD", ~S"""
    - **Dataset card / README frontmatter** other than `dataset_info` (task
      category, language, licence tags).
    - **PII gating**, HF's access-control settings are per-repo, out of scope here.
    - **Splits & configs directory conventions**, the auto-detector handles
      the common cases; a dedicated RFD if we hit an ambiguous layout.
    """

    details "Related RFDs", ~S"""
    - RFD 2183, retrain OmniGen for layer decomposition (consumer of these datasets)
    - RFD 2193, editscore as reproducibility bar (consumer)
    """

    details "Reference commit set", ~S"""
    - `chibifire/editreward-bench`, commit `057671b9…`, `.arrow` → parquet, viewer restored.
    - `chibifire/editscore-rl-train`, post-fix commit (row_group_size=100), 110 shards under
    `data/`.
    - `chibifire/editscore-reward-train`, post-fix commit, 97,256 rows written, no silent drops.
    """

    drafted_by :ai
  end
end
