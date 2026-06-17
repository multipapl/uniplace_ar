# Content & asset pipeline

How a level is described, how raw USDZ becomes bundled `.reality`, and what is allowed in Git.

## Two config files, on purpose

A level is described by **two** human-editable JSON files in `Content/TestLevel/`:

- **`LevelManifest.json`** — the global file: **what** loads, **how** it renders (each layer names
  its processing `type`), and **what relates to what** (the `spawn` empty). Holds **no** material
  knob values. Decoded by `LevelManifest` (`Loading/`).

  ```json
  { "id": "test", "title": "Test Scene",
    "spawn": { "entity": "StartPosition" },
    "layers": [ { "file": "Scene.usdz",   "type": "unlit"   },
                { "file": "Navmesh.usdz", "type": "navmesh" } ] }
  ```

- **`MaterialConfig.json`** — all material/processing **knobs**, grouped by layer `type`. A pipeline
  renders every layer of a type uniformly; the tunable values (e.g. glass opacity, navmesh
  `debugVisible`) belong here, not in the manifest. Decoded by `MaterialConfig`; `Params` is the
  union of all knobs and each processor reads only what it needs. New knobs are added as optional
  fields.

  ```json
  { "unlit": {}, "navmesh": { "debugVisible": false } }
  ```

Why split: the manifest is structural, the config is tuning. A non-programmer can edit either. See
[rendering.md](rendering.md) for who consumes the `type` and the knobs.

## The optimizer (`Tools/optimize_assets.py`)

Single-pass converter from raw USDZ (synced into the Resilio folder, `SYNC_DIR`) into bundled
layers in `Content/TestLevel/`:

- **Textured layers** → unzip → `realitytool compile` → a GPU-ASTC `.reality`. Stays compressed in
  VRAM.
- **Geometry-only layers** (no textures, e.g. the navmesh) → copied through as plain `.usdz`.

The manifest only ever names `.usdz`; the loader auto-prefers the `.reality` sibling
(`LevelResourceLocator`), so the manifest is never touched. Incremental via a sha256 cache; run on
demand (or via `optimize.command`) after Resilio finishes syncing.

**Two hard facts about the optimizer — do not relitigate:**
- `realitytool compile` **always** re-encodes textures to its own ~5 bpp ASTC and **ignores** any
  block-size flag. So there is no per-texture ASTC pre-pass; the ASTC→`.reality` step itself is the
  real win.
- The actual AR memory lever is **texture resolution**, and it is pulled **manually by the artist in
  the DCC**, never by the importer. `MAX_TEXTURE_SIZE = None` (compile at source resolution) is the
  default and must stay non-destructive — re-downscaling already-baked textures is a lossy
  double-downscale. The dormant `--max-size`/sips path is left unused, not removed.

## What goes in Git

Source code and project structure only. **Heavy content is gitignored and stays local** — USDZ/USD/
`.reality`/`.rcproject`, all textures (png/jpg/heic/exr/hdr/ktx…), audio, and video. Content flows
through Resilio + the optimizer, not through Git. The only committed assets are app-icon catalog
entries and the light UI images in `Content/UI/` (explicitly un-ignored in `.gitignore`).

Do **not** modify the read-only USDZ source (`UP_AVP_Incoming` / the sync folder) — it is shared
between the AVP and AR pipelines.
