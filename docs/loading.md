# Level loading

Everything downstream of placement only knows it receives a single `Entity` from a `LevelProvider`.
That protocol is the seam; the manifest-driven loader is the real implementation, with a runtime
placeholder as a safety net.

## The seam (`LevelProvider`)

```swift
protocol LevelProvider { func makeContent() async throws -> Entity }
```

Wired in `ARSessionController` as:

```swift
ManifestLevelProvider(fallback: PlaceholderLevelProvider())
```

- **`ManifestLevelProvider`** — loads a real level from its manifest. On any failure it logs and
  defers to the fallback, so the app never strands the user in an empty void before content exists.
- **`PlaceholderLevelProvider`** → `PlaceholderScene.build()` — a small **lit** room (floor + walls
  + center cube + a billboarded "PLACEHOLDER" label) generated entirely in code. Deliberately lit
  (not unlit) so it reads as obviously different from real baked content. Its floor carries a
  collider so teleport raycasts have a surface to hit.

## Manifest-driven load (`ManifestLevelProvider.loadFromManifest`)

1. Load `LevelManifest` and (optionally) `MaterialConfig` via `LevelResourceLocator`.
2. Build the standard `MaterialPipeline` and a shared `MaterialContext`.
3. For each manifest `layer`: resolve its file → `Entity(contentsOf:)` → run it through the
   pipeline for the layer's `type`, passing that type's params from the material config → add to a
   `SceneRoot`.
4. **Spawn alignment:** shift the whole `SceneRoot` so the `spawn.entity` empty lands at the origin.
   Only translation is applied — orientation stays the device's real heading.
5. Wrap in a `LevelContent` root and return it.

See [content-pipeline.md](content-pipeline.md) for the manifest vs material-config split, and
[rendering.md](rendering.md) for what the pipeline does to each layer.

## Resource resolution (`LevelResourceLocator`)

Resolves bundled files and, critically, **prefers a compiled `.reality` sibling over the `.usdz`
named in the manifest**. The optimizer ships textured layers only as `.reality`, so the manifest
never has to name anything but `.usdz`. Lookup tries the `TestLevel` subdirectory first, then a
flat-bundle fallback, so it works regardless of how Xcode lays the resources out. JSON configs
(`LevelManifest`, `MaterialConfig`) are decoded through the same locator.
