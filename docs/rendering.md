# Rendering — the material pipeline

A loaded layer is post-processed by exactly one **material processor**, chosen by the layer's
`type` string in the manifest. This replaces AVP's monolithic `MaterialPipeline.swift` with a thin
dispatcher + one small file per type, so adding a material type does not touch the loader or any
existing processor.

## Dispatcher (`MaterialPipeline`)

```swift
static func standard() -> MaterialPipeline {
    MaterialPipeline(processors: [
        "unlit":   UnlitProcessor(),
        "navmesh": NavmeshProcessor()
    ])
}
```

`process(entity, type:, params:, context:)` looks the type up in the registry and delegates. An
unknown type is logged and left unprocessed (non-fatal). This `standard()` factory is the **single
place** that knows which types exist.

## The protocol (`MaterialProcessor`)

```swift
protocol MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async
}
```

- **`params`** — the knobs for this type, read from `MaterialConfig` (see
  [content-pipeline.md](content-pipeline.md)). Each processor reads only the fields it cares about.
- **`context`** (`MaterialContext`) — shared state handed to every processor. Empty today; reserved
  so coupled types (e.g. a reflection environment that reflect + glass must agree on) can be added
  later **without changing the protocol**.

## Current processors

- **`UnlitProcessor`** (`type: "unlit"`) — the base visible layer. Recursively strips authored scene
  lighting (directional/point/spot/IBL components) and converts every material to `UnlitMaterial`
  with `applyPostProcessToneMap: false`, so baked lighting in the textures shows exactly as authored
  with zero realtime lighting cost. PBR/Simple → Unlit (copying baseColor, blending,
  opacityThreshold); ShaderGraph passes through; all get `faceCulling = .none`.
- **`NavmeshProcessor`** (`type: "navmesh"`) — the navigation mesh (AVP's "Walkable", renamed):
  invisible geometry that defines where teleport is allowed. Generates precise static-mesh collision
  so teleport raycasts land only on valid floor, then removes the visible mesh. The `debugVisible`
  knob (in `MaterialConfig`) instead draws it as a translucent cyan overlay for tuning.

## Adding a layer type

1. New file `Rendering/<Name>Processor.swift` conforming to `MaterialProcessor`.
2. Register it in `MaterialPipeline.standard()` (one line).
3. Add any new knobs as optional fields on `MaterialConfig.Params`.

No changes to the loader, the manifest schema, or other processors. Phase 1 ships only `unlit` +
`navmesh`; `glass`, `reflect`, etc. are the intended next types.
