# AGENTS.md — entry point for the model

UniPlace AR (`UP_AR`) is a native iPad/iPhone **portal viewer**: ARKit is used purely as a
6DoF tracker, the camera feed is hidden, and the device is a handheld window into a fully
virtual apartment. You physically walk your real room to move through the scene; teleport and
recenter are the other two ways to move. It is a sales-grade presentation tool, the iPad epoch
of the same project shipped on Apple Vision Pro (`/Users/a11/Projects/UP_AVP`, read-only lineage).

This file is the doc index and the rules you operate under. Read the relevant doc before
touching a subsystem; the docs are kept short on purpose.

## Documentation map

- **[docs/architecture.md](docs/architecture.md)** — module map, the app flow, and the seams that
  hold it together. Start here.
- **[docs/ar-session.md](docs/ar-session.md)** — the portal trick, floor calibration, teleport,
  recenter, and the scene-hierarchy pivot. The core experience.
- **[docs/loading.md](docs/loading.md)** — how a level is loaded: the `LevelProvider` seam, the
  manifest-driven loader, resource resolution, and the placeholder fallback.
- **[docs/rendering.md](docs/rendering.md)** — the modular `MaterialPipeline` (dispatcher +
  per-type processors) and how to add a new layer type.
- **[docs/content-pipeline.md](docs/content-pipeline.md)** — manifest vs material-config, the
  `optimize_assets.py` asset pipeline, the `Content/` layout, and what stays out of Git.
- **[docs/Founding Brief.md](docs/Founding%20Brief.md)** — the product source of truth (what we
  build, in what order, the phases). Not written by the model; do not edit.
- **[docs/Enviz Reference.md](docs/Enviz%20Reference.md)** — fact-only reference for the product
  category. Not written by the model; do not edit.

## Rules for the model

**Documentation discipline.**
- Do **not** write or change documentation in the middle of a work session. Docs describe
  *committed* reality, never work-in-progress. Finish the code change, commit it, *then* update
  the affected doc as a follow-up.
- Keep docs short and one-topic-per-file. If a doc starts growing into a manual, that is a smell —
  trim it, don't add volumes. The docs exist so the next session finds facts fast.
- Reference subsystems by file/module name, not line numbers (they go stale).
- `Founding Brief.md` and `Enviz Reference.md` are human-authored source-of-truth docs — read
  them, never edit them.

**Assets and Git.**
- **Never add heavy assets to Git.** USDZ/USD/`.reality`, textures, audio, and video are
  gitignored and must stay that way. The repo holds source code and project structure only;
  content lives locally and flows through Resilio + `optimize_assets.py`. See
  [docs/content-pipeline.md](docs/content-pipeline.md).
- Do not modify the read-only USDZ source (`UP_AVP_Incoming` / the Resilio sync folder). It is the
  shared data source for both AVP and AR.
- The asset optimizer stays **non-destructive**: it compiles at source texture resolution
  (`MAX_TEXTURE_SIZE = None`). Texture downscaling is a deliberate manual step in the DCC, not in
  the importer. Do not add auto-downscale.

**Code.**
- Keep files small and single-responsibility (see the architecture principles in the brief). One
  file should not swallow half a reading context — the AVP monolith is what this project avoids.
- Commit or push only when the user asks.
