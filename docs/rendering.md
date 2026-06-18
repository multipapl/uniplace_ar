# Rendering — the material pipeline

A loaded layer is post-processed by exactly one **material processor**, chosen by the layer's
`type` string in the manifest. This replaces AVP's monolithic `MaterialPipeline.swift` with a thin
dispatcher + one small file per type, so adding a material type does not touch the loader or any
existing processor.

## Dispatcher (`MaterialPipeline`)

`MaterialPipeline.standard()` is the **single place** that knows which types exist — a registry
mapping each `type` string to its processor. `process(entity, type:, params:, context:)` looks the
type up and delegates; an unknown type is logged and left unprocessed (non-fatal).

## The protocol (`MaterialProcessor`)

```swift
protocol MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async
}
```

- **`params`** — the knobs for this type, from the manifest's `materials` section. Each processor
  reads only the fields it cares about.
- **`context`** (`MaterialContext`, a reference type) — shared per-load state: the `worldRoot` (where
  shared IBL lights attach), a bundle resource `resolve` closure, the shared `ReflectionEnvironment`,
  and the `probesScene`. This is how coupled types agree on the same state.

Common recursion (strip authored lighting, PBR→Unlit conversion, tint maths, reflection-receiver
walk, UV re-pointing) lives in `MaterialSupport.swift` so processors stay small.

## Processors

- **`unlit`** — base visible layer: strip authored lighting, convert every material to `UnlitMaterial`
  (`applyPostProcessToneMap: false`) so baked lighting shows as authored with zero realtime cost.
- **`emission`** — self-lit surfaces split into their own layer: unlit, with the baked colour pushed
  past 1.0 by a tint × brightness multiplier (`emissionBrightness`, default ×2) so it reads as a light
  source. Its own type so it can diverge to additive/bloom later.
- **`skybox`** — the shared sky dome: unlit, tinted/brightened, depth-writing background.
- **`translucent`** — alpha-tested cutout (foliage). Drives the hard clip from the opacity mask;
  needs the multi-UV handling below.
- **`curtains`** — sheer fabric: unlit, tinted, semi-transparent, depth pre-pass sort.
- **`reflect`** — glossy non-glass surfaces: keeps PBR, optionally unpacks an ORM atlas, attaches a
  reflection receiver. Multi-UV.
- **`glass`** — generated transparent PBR + reflection receiver.
- **`water`** — keeps its authored ShaderGraph material + reflection receiver only.
- **`fire`** — animated fire: a looping alpha `VideoMaterial`. The clip is named by `fireVideo` and
  resolved from `Content/Videos/`. See the video note below.
- **`probes`** — invisible anchor planes; registers one IBL per probe into the shared
  `ReflectionEnvironment`, then hides the geometry. Ordered **before** reflect/glass/water.
- **`navmesh`** — invisible nav surface: precise static-mesh collision for teleport, then hidden
  (`debugVisible` draws it as a cyan overlay for tuning).

## Reflections (`ReflectionEnvironment`)

The `probes` layer's planes mark where a 360° reflection was captured; each plane name maps (via
`Content/ProbesTextures/probes.json`) to an extracted equirect env map. One IBL light is built per
probe; reflect/glass/water point each model at the **nearest** probe. Two-probe blending is deferred
(see docs/backlog.md). Probe maps are downscaled to 512 by the optimizer (cheap IBL).

## Looping video (`fire`)

`LoopingVideoPlayback` (ported from the AVP fire path, where the video-decoder grief was solved) wraps
an `AVQueuePlayer` + `AVPlayerLooper`: muted, stall-minimisation off, a small forward buffer, plus a
keep-alive task and a `timeControlStatus` observer that re-arm playback the instant anything pauses the
player out from under us — without this the looping texture silently freezes. `FireProcessor` builds the
`VideoMaterial`, applies it across the subtree, and attaches the playback via `FireVideoComponent` so the
player's lifetime tracks the entity: a full scene teardown releases the component and `deinit` pauses the
decoder. No app-level bookkeeping. The clip is a static media file (see content-pipeline.md), not a
pipeline-produced layer.

## Multi-UV materials

Baked layers with >1 texture split them across two UV sets (baked base colour on UV1, everything else
on UV0); RealityKit imports the wrong indices, so processors force them via manifest knobs
(`*BaseColorUVIndex`, `*MaterialUVIndex` / `*AlphaUVIndex`). See the convention note in `AGENTS.md`.

## Adding a layer type

1. New file `Rendering/<Name>Processor.swift` conforming to `MaterialProcessor`.
2. Register it in `MaterialPipeline.standard()` (one line).
3. Add any new knobs as optional fields on `MaterialConfig.Params`.

No changes to the loader, the manifest schema, or other processors.
