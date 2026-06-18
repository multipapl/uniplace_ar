# Content & asset pipeline

How a level is described, how raw USDZ becomes bundled `.reality`, and what is allowed in Git.

## One combined manifest

A level is described by a **single** human-editable file, `Content/LevelManifest.json`, with three
sections:

```json
{ "shared":  [ { "file": "Skybox.usdz", "type": "skybox" } ],
  "scenes":  [ { "id": "floor", "title": "Поверх",
                 "spawn": { "entity": "LO_StartPosition" },
                 "layers": [ { "file": "LO_Scene.usdz", "type": "unlit" }, … ] }, … ],
  "materials": { "reflect": { "reflectBaseColorUVIndex": 1, "reflectMaterialUVIndex": 0 }, … } }
```

- **`shared`** — layers loaded for every scene (the skybox).
- **`scenes`** — the selectable scenes (`floor`/`terrace`), each with its own `spawn` + `layers`.
  The apartment is split in two because a phone can't hold both at once; only one scene's layers are
  resident at a time. Each layer names a `file` + a processing `type`.
- **`materials`** — material knobs grouped by `type` (scene-independent: glass is glass everywhere).
  Folded into this one file on purpose — there is no separate material-config file.

Decoded by `LevelManifest`; `materials` decodes to `MaterialConfig`. See [rendering.md](rendering.md)
for who consumes the `type` and the knobs, and [loading.md](loading.md) for the load flow.

## The optimizer (`Tools/optimize_assets.py`)

Single-pass converter from the raw USDZ layers in the Resilio sync folder (`SYNC_DIR`) into
`UP_AR/Content/`:

- **Routing by filename prefix** → a scene subfolder: `LO_*` → `Floor/`, `TR_*` → `Terrace/`, no
  prefix → `Shared/`. The prefix is kept in the output name so every layer is globally unique.
- **Textured layers** → unzip → (optional downscale) → `realitytool compile` → a GPU-ASTC `.reality`.
- **Geometry-only layers** (e.g. navmesh) → copied through as plain `.usdz`.
- **Probe layers** (`*_Probes`) → their plane env maps are extracted to `Content/ProbesTextures/` +
  `probes.json` (plane→texture) for the runtime IBL.

The manifest only names `.usdz`; the loader auto-prefers the `.reality` sibling. Incremental via a
sha256 cache kept at the repo root (out of `Content/` so it is never bundled). Run on demand (or via
`optimize.command`) after Resilio finishes syncing.

### Texture caps (`--max-size`)
The memory lever is **texture resolution**. `--max-size N` downscales any texture whose longest edge
exceeds `N` (non-destructive: it works on a temp copy, never the source usdz; the sha256 cache rebuilds
affected layers). Per-layer overrides, regardless of the global cap:

- **Probe maps → 512** (they feed IBL cubemaps, heavy in VRAM; 512 equirect is plenty).
- **Skybox → never capped** (must stay 8k or the sky reads as mush).

`realitytool compile` always re-encodes textures to its own ASTC and ignores any block-size flag, so
there is no per-texture ASTC pre-pass — the resolution cap is the real win. Note: `.reality` size on
disk ≈ ASTC texels only; runtime RAM is larger (engine/AR baseline + mipmaps + IBL cubemaps).

## What goes in Git

Source code and project structure only. **Heavy content is gitignored and stays local** — USDZ/USD/
`.reality`, textures, audio, video, plus the generated optimizer output folders
(`Content/Floor|Terrace|Shared|ProbesTextures`). The only committed level data is the hand-authored
`Content/LevelManifest.json` and the light UI images in `Content/UI/`.

Do **not** modify the read-only USDZ source (`UP_AVP_Incoming` / the sync folder) — it is shared
between the AVP and AR pipelines.
