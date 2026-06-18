# Level loading

Everything downstream of placement only knows it receives a single `Entity` from a `LevelProvider`.
That protocol is the seam; the manifest-driven loader is the real implementation, with a runtime
placeholder as a safety net.

## The seam (`LevelProvider`)

```swift
protocol LevelProvider { func makeContent() async throws -> Entity }
```

Built per load in `ARSessionController` from the menu's scene choice:

```swift
ManifestLevelProvider(sceneId: appModel.selectedSceneId, fallback: PlaceholderLevelProvider())
```

- **`ManifestLevelProvider`** — loads one scene from the manifest. On any failure it logs and defers
  to the fallback, so the app never strands the user in an empty void before content exists.
- **`PlaceholderLevelProvider`** → `PlaceholderScene.build()` — a small **lit** room generated in
  code (deliberately lit so it reads as obviously not real baked content). Its floor carries a
  collider so teleport raycasts have a surface to hit.

## One combined manifest, two scenes

`Content/LevelManifest.json` is the single settings file (structure **and** material knobs — there is
no separate material-config file). It has three sections: `shared` (layers loaded for every scene,
e.g. the skybox), `scenes` (the selectable scenes — `floor`/`terrace`, each with its own `spawn` and
`layers`), and `materials` (knobs grouped by processing `type`). A phone can't hold both scenes at
once, so the loader resolves **one scene at a time**. See [content-pipeline.md](content-pipeline.md).

## Manifest-driven load (`ManifestLevelProvider.loadFromManifest`)

1. Decode `LevelManifest` via `LevelResourceLocator`; look up the chosen scene by `sceneId`.
2. Build the standard `MaterialPipeline` and a `MaterialContext` (carrying the `SceneRoot` as world
   root + a resource resolver + the shared reflection environment).
3. For each layer in `shared + scene.layers` (in order): resolve its file → `Entity(contentsOf:)` →
   run it through the pipeline for the layer's `type` with that type's knobs → add to `SceneRoot`.
   Order matters: the `probes` layer precedes the reflective layers that consume it.
4. **Spawn alignment:** shift the whole `SceneRoot` so the scene's `spawn.entity` empty lands at the
   origin. Only translation is applied — orientation stays the device's real heading.
5. Wrap in a `LevelContent` root and return it.

## Resource resolution (`LevelResourceLocator`)

Resolves bundled files and **prefers a compiled `.reality` sibling over the `.usdz`** named in the
manifest (the optimizer ships textured layers only as `.reality`, so the manifest never names anything
but `.usdz`). Lookup searches the content subfolders (`Shared`, `Floor`, `Terrace`, `ProbesTextures`)
then a flat-bundle fallback; layer file names are globally unique (LO_/TR_ prefixes) so no
scene→folder mapping is needed. The manifest JSON is decoded through the same locator.
