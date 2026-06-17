# AR session — the portal, calibration, teleport

This is the core experience. `ARSessionController` owns it; `PortalEnvironment` configures the
view; `SceneHierarchy` + `LocomotionController` handle movement.

## The portal trick (`PortalEnvironment`)

Not classic AR. ARKit world tracking drives the rendered camera 1:1, but the passthrough video is
**replaced by a flat virtual background**, so the iPad reads as a window into a virtual room rather
than an AR overlay.

- `configure(_:)` — shared setup: `cameraMode = .ar`, scene-understanding off, motion blur / DoF /
  grain disabled.
- `showCalibrationFeed(_:)` — passthrough camera feed, shown only while calibrating so the user can
  aim at the real floor.
- `showPortalBackground(_:)` — the flat virtual background that hides the feed in the placed scene.
- `makeConfiguration()` — `ARWorldTrackingConfiguration` tuned for the portal: horizontal planes
  only, no environment texturing, light estimation off, gravity alignment, and the lightest
  ≥60 FPS video format (tracking cost down, framerate up).

## Floor calibration

While in `calibrating`, a `CADisplayLink` tick (`updateCalibrationReadout`) probes for the floor
under the screen-center reticle and shows a translucent preview grid once tracking has settled
(`calibrationPreviewDelay`).

The floor pose is resolved by `currentCalibrationFloorTransform()`, which is fussy on purpose: the
preview must always sit **under the reticle** (what the user aims). It uses a direct reticle
raycast when it can; otherwise it takes only the floor *height* from sampled points / the largest
horizontal plane and re-projects the camera-forward ray onto that height. It never falls back to an
off-center sample or a plane center — that is what used to make the grid slide sideways.

On confirm (`confirmCalibration`), the eye height is `camera.y − floor.y`; the scene is then placed.
There is a simulator fallback (identity transform, 1.4 m eye height) so the flow stays testable
without AR.

## Scene placement & hierarchy (`SceneHierarchy`)

`placeScene` asks the `LevelProvider` for content, then builds the pivot tree:

```
originAnchor (calibrated floor pose)
└── locomotionRoot (teleport / recenter offset ONLY)
    └── sceneContent (the level)
```

- **Physical walking** is free: ARKit moves the camera through this static tree.
- **Teleport / recenter** mutate `locomotionRoot` only — the raw sensor pose is never overwritten
  (a hard rule from the brief: teleport is an offset, not a pose write).
- **`nudgeHeight`** shifts `originAnchor.y` to correct a floor-height estimate.

## Teleport

One zero-delay long-press recognizer drives both phases (`handlePress`):

- In **calibrating**, a press-release confirms the floor.
- In **placed**, press/drag shows and moves a teleport target disc on the floor
  (`updateTeleportPreview`), and release teleports there (`commitTeleport` → `performTeleport`).

The floor target comes from a hit-test filtered by `LocomotionController.isPlausibleTarget`
(rejects non-finite / absurdly distant hits). The shift itself is
`LocomotionController.teleportShift` — horizontal only, vertical component dropped so teleport never
changes the viewer's height. `LocomotionController` is pure `simd` math with no RealityKit/ARKit
deps so it is unit-testable.

## Debug read-outs

The `ARSessionDelegate` and the display-link `tick` feed FPS / tracking state / pose into
`AppModel`, but only when the debug overlay is on. Frame-callback work hops to the main actor at
~10 Hz max to stay cheap. First-frame / first-floor / scene-placed events are logged via
`TimingDiagnostics` and `MemoryDiagnostics`.
