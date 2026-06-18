# Architecture

The app is deliberately modular: a thin entry point and small, single-responsibility files grouped
by concern. RealityKit/ARKit plumbing is quarantined in `AR/` and `Navigation/`; the rest of the
app only talks to it through narrow protocols.

## App flow

Four phases, driven by `AppPhase` and switched on in `RootView`:

```
start ──(pick a scene)──▶ calibrating ──(tap floor)──▶ loading ──(fully loaded)──▶ placed
                              ▲                                                       │
                              └─────────────────── recalibrate ◀─────────────────────┘
```

- **start** — `StartView`, a scene picker (one button per scene, listed from the manifest). Picking a
  scene sets `selectedSceneId` and enters calibration. Pure SwiftUI — **no AR runs here**, so the
  menu appears instantly with nothing heavy before it.
- **calibrating** — aim the reticle at the floor. Nothing heavy runs yet — the level is **not**
  loaded here, so the calibration camera stays smooth. The tap sets the origin and the eye height.
- **loading** — floor confirmed; the level loads **now**, behind a loading screen that covers the
  scene until it is **fully** loaded and has rendered (no half-built pop-in, no confirm freeze).
- **placed** — the level is anchored on the floor; physical walking, teleport, and recenter are live.

The AR shell is only spun up on scene selection (not at launch): `openVirtualCamera` calls
`beginShellWarmup`, `RootView` mounts the `ARView` for non-`start` phases, and `LoadingView` covers it
until ready. See `AppModel` and `ARSessionController`'s `placeScene`.

## Module map

- **`App/`** — `UP_ARApp` (entry point), `AppPhase` (the flow enum), `AppModel` (the single
  observable source of truth: phase, presentation read-outs, HUD toggles). `AppModel` holds **no**
  AR code — it expresses intent through the `ARExperienceActions` delegate.
- **`Screens/`** — SwiftUI layers: `RootView` (phase switch + overlay composition), `StartView`,
  `CalibrationOverlay` (reticle + prompts, lets taps through), `LoadingView`,
  `BlurredCoverBackground`.
- **`AR/`** — `ARViewContainer` (SwiftUI↔UIKit bridge, hosts the `ARView` in a view controller for
  clean rotation), `ARSessionController` (the coordinator: session lifecycle, tap handling,
  calibration, teleport, debug read-outs; implements `ARExperienceActions`), `PortalEnvironment`
  (the hidden-feed portal config). See [ar-session.md](ar-session.md).
- **`Navigation/`** — `SceneHierarchy` (the locomotion pivot tree) and `LocomotionController` (pure,
  testable teleport math, no RealityKit deps).
- **`Loading/`** — the level-loading seam and its implementations. See [loading.md](loading.md).
- **`Rendering/`** — the modular material pipeline. See [rendering.md](rendering.md).
- **`HUD/`** — `PresentationHUD` (minimal edge HUD for the placed phase: recenter + a menu with
  floor-height nudge, recalibrate, debug toggle). Presentation-grade only.
- **`Diagnostics/`** — `TimingDiagnostics` (cold-start/session stopwatch logs), `MemoryDiagnostics`
  (physical-footprint read-out; memory is the hard limit, measured from Phase 1), `DebugOverlay`
  (FPS/tracking/pose, gated behind the menu toggle).
- **`Content/`** — the hand-authored `LevelManifest.json`, light UI images (`UI/`), the optimizer's
  generated (gitignored) scene folders `Floor/`/`Terrace/`/`Shared/`/`ProbesTextures/`, and static media
  in `Videos/`. See [content-pipeline.md](content-pipeline.md).
- **`Tools/`** — `optimize_assets.py` + `optimize.command`, the local asset converter.

## The seams (where to plug in without touching everything)

1. **`AppModel` ↔ AR** via the `ARExperienceActions` protocol. The model fires intent
   (`beginCalibration`, `recenter`, `recalibrate`, `nudgeHeight`); `ARSessionController` implements
   it. Keeps the model free of AR plumbing.
2. **Level loading** via the `LevelProvider` protocol. `ARSessionController` only knows it gets an
   `Entity` from `makeContent()`. The wired provider is `ManifestLevelProvider(sceneId:)` (the id from
   the menu) with a `PlaceholderLevelProvider` fallback.
3. **Material processing** via the `MaterialProcessor` registry in `MaterialPipeline`. A manifest
   layer's `type` string selects a processor; adding a type is a new file + one registration line.

These three seams are why a subsystem can be swapped (placeholder→real content, add a glass
material type, change the AR backend) without rippling through the app.
