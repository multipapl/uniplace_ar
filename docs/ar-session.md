# AR session — the portal, calibration, teleport

This is the core experience. `ARSessionController` owns it; `PortalEnvironment` configures the
view; `SceneHierarchy` + `LocomotionController` handle movement; the audio controllers are built only
after a scene is placed.

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
  only, no environment texturing, light estimation off, gravity alignment, autofocus locked (the
  portal hides the feed, so focus hunting would only add pose jitter). On LiDAR devices it turns
  on `sceneReconstruction = .mesh` — not for occlusion (the portal hides passthrough) but because the
  depth mesh makes floor detection near-instant and steadies tracking. Video format scales with the
  device: capable (LiDAR) devices take the **highest-resolution** ≥60 FPS feed — more visual features
  → steadier tracking — while weaker devices keep the **lightest** ≥60 FPS format to protect the
  framerate.

## Floor calibration

While in `calibrating`, a `CADisplayLink` tick (`updateCalibrationReadout`) probes for the floor
under the screen-center reticle and shows a translucent preview grid once tracking has settled
(`calibrationPreviewDelay`).

The floor pose is resolved by `currentCalibrationFloorTransform()`, which is fussy on purpose: the
preview must always sit **under the reticle** (what the user aims). It uses a direct reticle
raycast when it can; otherwise it takes only the floor *height* from sampled points / the largest
horizontal plane and re-projects the camera-forward ray onto that height. It never falls back to an
off-center sample or a plane center — that is what used to make the grid slide sideways.

On confirm (`confirmCalibration`), the origin is placed **under the user's feet, facing the authored
spawn direction**:

- **Position**: floor *height* from the reticle hit, *horizontal* position from the camera. Combined
  with the spawn alignment in `ManifestLevelProvider` (which slides the scene so its spawn empty sits
  at the origin), the iPad physically stands on the scene's `*_StartPosition` empty at load.
- **Facing**: the origin also carries a yaw from `LocomotionController.spawnOriginYaw`, computed from
  the camera's heading and the manifest `spawn.yawDegrees`. Because the spawn empty sits at the origin,
  this rotates the scene about the user's feet, so the viewer looks down the authored direction no
  matter which way the iPad physically points. `yawDegrees: 0` ⇒ face the scene's local −Z.

The eye height is `camera.y − floor.y`. There is a simulator fallback (identity transform, 1.4 m eye
height) so the flow stays testable without AR.

## Scene placement & hierarchy (`SceneHierarchy`)

`placeScene` asks the `LevelProvider` for content, then builds the pivot tree:

```
originAnchor (calibrated floor pose, driven by a tracked ARAnchor)
└── calibrationRoot (manual height nudge ONLY)
    └── locomotionRoot (teleport / recenter offset ONLY)
        └── sceneContent (the level)
```

- **Anchoring**: on device, `originAnchor` binds to a session-managed `ARAnchor` (`AnchorEntity(anchor:)`),
  not a fixed `AnchorEntity(world:)`. ARKit keeps that anchor pinned to the physical floor as it
  refines its world map (loop closure / relocalization), so map corrections no longer surface as
  visible horizontal/vertical jumps. The simulator / no-AR path falls back to a fixed world anchor.
  `detachFromSession()` drops the ARAnchor on scene unload so anchors don't leak across switches.
- **Physical walking** is free: ARKit moves the camera through this tree.
- **Teleport / recenter / snap-turn** mutate `locomotionRoot` only — the raw sensor pose is never
  overwritten (a hard rule from the brief: teleport is an offset, not a pose write).
- **`nudgeHeight`** shifts `calibrationRoot.y` (not `originAnchor.y`, which ARKit now drives) to
  correct a floor-height estimate.

## Teleport

One zero-delay long-press recognizer drives both phases (`handlePress`):

- In **calibrating**, a press-release confirms the floor.
- In **placed**, press/drag shows and moves a teleport target disc on the floor
  (`updateTeleportPreview`), and release teleports there (`commitTeleport` → `performTeleport`). If
  the press starts on the HomePod's visual bounds, release opens the audio panel instead. That the
  HomePod is tappable is signalled by a **Fresnel rim glow** that fades in as the viewer approaches
  (`updateHomepodRim`, on the tick) — the handheld stand-in for a hover state; see the rendering doc.

The floor target comes from a hit-test filtered by `LocomotionController.isPlausibleTarget`
(rejects non-finite / absurdly distant hits). The shift itself is
`LocomotionController.teleportShift` — horizontal only, vertical component dropped so teleport never
changes the viewer's height. `LocomotionController` is pure `simd` math with no RealityKit/ARKit
deps so it is unit-testable.

**Marker appearance** (`makeTeleportPreviewDisc`) — a flat unlit plane ~0.4 m across, lifted ~3 cm
off the floor so it draws above rugs rather than z-fighting under them, with a subtle looping scale
pulse. The pulse lives on the disc, which is a *child* of the anchor that follows the finger, so the
per-touch repositioning moves the parent only and never disturbs the animation (the decoupling that
avoids flicker). The art is overridable: a square alpha-gradient PNG in the `TeleportMarker`
asset-catalog image becomes the disc texture, its alpha shaping the silhouette and soft edge; with no
such image it falls back to a procedurally rounded cyan disc. The texture is preloaded once at scene
placement so the first teleport gesture never loads mid-drag.

## Runtime controls

The placed HUD exposes:

- **Recenter** — `SceneHierarchy.recenter()`, clearing the locomotion offset back to the calibrated
  spawn.
- **Snap-turn** — rotates `locomotionRoot` by ±45° around the user's current ground point.
- **Height nudge** — shifts `originAnchor.y` in 5 cm steps and mirrors the correction in `AppModel`.
- **Open Level** — calls `reloadSelectedScene()` and swaps floor/terrace behind `LoadingView` without
  asking for floor calibration again.
- **Audio** — opens `NowPlayingCard` when the scene has a configured HomePod / tracks.

On runtime scene switches, the controller tears down the old anchor and audio controllers before
loading the replacement scene, so memory does not peak with two levels resident.

## Scene audio

`ARSessionController` configures the iOS audio session once, then builds audio from loaded content:

- **HomePod music** — `HomepodProcessor` places a `MusicEmitter` in the layer; after placement the AR
  controller finds it, scans `Content/Audio/`, prewarms the first track behind `LoadingView`, and
  mirrors player state into `AppModel`.
- **Ambient SFX** — manifest `ambient.sources` map `SFX_*` empties to looping clips in `Content/SFX/`;
  `rooftopFile` is an optional non-positional ambience entity under `locomotionRoot`.
- **Mixer** — `NowPlayingCard` exposes the music channel plus live SFX channels through
  `setAudioChannelVolume`.

## Debug read-outs

The `ARSessionDelegate` and the display-link `tick` feed FPS / tracking state / pose into `AppModel`,
but only when the debug overlay is on. The same display link updates the music panel position while it
is open. Frame-callback work hops to the main actor at ~1 Hz for tracking read-outs to stay cheap.
First-frame / first-floor / scene-placed events are logged via `TimingDiagnostics` and
`MemoryDiagnostics`.
