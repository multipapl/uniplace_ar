# Founding Brief — iPad / iPhone Portal Viewer

This is the authoritative starting document for the project. It describes what we are
building and in what order. The other note in this folder (`Enviz Reference.md`) is a
fact-only reference about the product category we draw from. This brief is the source of truth.

The build is **native** (RealityKit + ARKit, iOS / iPadOS).

## Background / Lineage

This is the latest epoch of one ongoing mega-project — the same architectural apartment,
expressed in different forms over time. The previous epoch is the **Apple Vision Pro version**:
a high-quality immersive headset experience, already built and distributed.

This iPad/iPhone version is a new format of that same project. It is not built from scratch:
we **reuse the AVP scene content and, where it makes sense, its code and feature work**. The AVP
build is both our lineage and our reuse source.

**Identity (per the boss):** this is a **separate app**, not connected to the AVP app, but it
will carry the **same app icon and the same name** — to give the illusion that it is "the same
thing." It is not, but it should look like one product family.

**Apple account:** the AVP app was built under the **studio** developer account. This app is
built under the developer's **personal** account, which has been added to the studio team as an
**admin** — so studio capabilities remain available. Bundle ID is **separate** from the AVP app.

## What It Is

- **Not classic AR.** The iPad/iPhone is a **handheld portal / virtual camera** into a fully
  virtual scene. The real world is **not** shown on screen.
- ARKit is used **purely as a 6DoF tracker** (visual-inertial device pose). The camera feed is
  hidden; the background is the virtual scene.
- **The core feature:** you pick up the iPad and physically **walk around your real space**, and
  the app tracks the device in 3D so you move through the virtual scene. This is the main thing
  the AVP version could *not* do — there you could not physically walk more than ~0.5 m. Here you
  can take the iPad and go for a walk.

Three ways to move (same set as the AVP version, but now with real walking):

1. **Physical movement (primary):** your real position + the iPad's tilt and position drive the
   camera. Walk physically → move in the virtual scene.
2. **Teleport:** tap a spot on the floor on the iPad → appear there.
3. **Hotspots:** jump to defined points of interest.

Reference for the interaction category: Enviz (see `Enviz Reference.md`).

## Product Intent

- A **sales-grade presentation tool**, not a technical demo.
- Success = the user feels: *"I am holding a portal into this apartment."*
- Two priorities, above every feature:
  1. **Visual quality** — must not feel like a downgrade from the AVP work.
  2. **Virtual-camera feel** — stable, smooth, grounded, convincing in the hands.

## Source Content

- **AVP project (reuse source):** `/Users/a11/Projects/UP_AVP` — the Xcode project with all its
  content. Look here for reusable scene assets, materials, and feature code.
- **USDZ source:** `/Users/a11/Projects/UP_AVP_Incoming` — a Resilio-synced folder that holds all
  USDZ files. This is the **read-only data source** — **do not modify it.** The AVP project pulls
  files out of it via a script into the project; this project should do the same.
- **Footprint:** the scene runs at roughly **4 GB** on Vision Pro. That is the weight we must cut
  down to fit a 4 GB iPad (see Constraints).

**Asset pipeline:** the `UP_AVP_Incoming` folder stays the live working source, and the USDZ files
are likely **shared between AVP and AR**. AR gets its **own version of the converter script** that
outputs a more compressed / lossier format (smaller, more aggressive than AVP's). On top of that,
some textures need **manual** optimization (e.g. down to 2K or 1K). Consequence to keep in mind:
because AVP and AR diverge in optimization, a content change at the source may have to be
**replicated in both pipelines** (once for AVP, once for AR).

## Version Control & Assets

- Code and project structure are versioned in Git / GitHub.
- **Content assets are NOT committed or pushed** — RealityKit content, `.reality` files, USDZ, and
  heavy textures/resources live **locally only** and are gitignored. The repo stays light; assets
  flow through Resilio / the converter script, not through Git.

## Target Devices & Distribution

- **Floor device:** iPad Air 4 (A14, 4 GB RAM, no LiDAR — fine, no occlusion needed for a portal).
- Also **iPhone 12+** (12 = 4 GB, 14 = 6 GB). At the shell level the iPad/iPhone difference is
  small (one universal app, smaller iPhone screen). iPad-first, iPhone follows.
- **Orientation:** support **both** portrait and landscape.
- **Frame rate:** target **60 FPS**.
- **Minimum iOS:** not a priority — it just needs to run on current devices. Set pragmatically to
  **iOS 18** (modern RealityKit / RealityView; all test devices run it). Lower later only if a real
  device needs it.
- **Bundle ID:** separate from the AVP app.
- **Distribution:** TestFlight, under the personal account (admin on the studio team). Many
  personal iPhones/iPads are available, so a wide internal test group is easy.

## Constraints

- **Memory is the hard limit.** Budget ~2 GB of the 4 GB for one level. The old "load everything
  at once" approach does not fit — load / stream per section.
- **Scale is exactly 1 real metre = 1 virtual metre.** Movement must map 1:1. (The AVP immersive
  build already renders at 1:1 real scale, so the scene is almost certainly authored in real
  metres — that is our reference; confirm on device with a quick tape check.)

## Architecture Principles

Design this modular from the start. The AVP app has a monolithic ~2000-line `AppView`, which is
hard to maintain and hard to work on. We do not want that here.

- A thin entry point (App + a small root view), not a god-object view.
- **Separate concerns into their own files/folders:** UI / screens, AR session & tracking,
  locomotion (calibration / teleport / recenter), content loading, rendering setup, HUD, debug.
- Single-responsibility, small files. One file should not swallow half of a reading context.
- The goal is not architectural purity for its own sake — just a sensibly designed app that is
  maintainable, scalable, and easy to reuse code from.

## Phases

### Phase 1 — Shell (mechanics on a primitive)

Prove the **entire core loop** works with zero content weight. Phase 1 is not just a tracking
test — by the end it should have all the main functionality, just with a cube instead of the
apartment.

Expected user flow (mirrors the AVP app's flow):

1. App opens to a **simple start screen** with a single entry button (e.g. "Open Virtual Camera").
2. Tapping it starts **floor calibration**: aim the camera at the floor, tap to set it (or place
   points); that becomes the start position. The virtual camera height matches the real iPad height
   above the floor.
3. After calibration, the **cube** (or whatever placeholder we use) appears, anchored on the floor.

In that placed state, all core functionality must work:

- **Physical walking** around the cube — the portal camera follows the iPad in 3D.
- **Teleport** — tap a spot to move there.
- **Reset / recenter** — recover if you get stuck or tracking goes wrong.
- A **minimal edge HUD** (menu, recenter).

Background can be anything simple (grey, an HDRI, a placeholder scene) — what matters here is how
the cube behaves and how the core loop feels, not the background.

**Done when:** the app installs and runs; the start → calibrate → placed flow works; and physical
walking, teleport, and reset are all functional and feel stable on iPad Air 4. This is the full
core experience minus real content.

### Phase 2 — Content & Optimization

Replace the cube with the real apartment and make it fit the device.

- Bring the AVP scene content in (beauty-bake materials reused **as-is**, not re-authored), pulling
  USDZ from the read-only `UP_AVP_Incoming` source via a script, as the AVP project does.
- Start with **one level**: living room + kitchen, first floor.
- **Optimization, automatic and manual:** cut textures, lower resolution, harsher ASTC block
  compression, reduce / reorganize heavy assets. Expect both an automated pass and hand work.
- **Split the floors into two** (lower floor and terrace above) so each fits the memory budget;
  load per section rather than all at once. We likely cannot keep both levels loaded at the same
  time — to be confirmed on device.

**Done when:** one real level looks sales-grade and runs stable on iPad Air 4 within budget.

### Phase 3 — Presentation Polish & Feature Ports

After the core looks and feels right.

- Hotspots / points of interest and teleport targets placed in the real scene.
- Refine recovery (return to start / nearest hotspot) and HUD.
- Tune scale and comfort for presentation use.
- Add the terrace level if memory allows.
- **Port selected AVP features** that make sense in AR — e.g. spatial audio (the AVP version
  positions spatial audio sources from a USD file of empties exported from Blender). These are
  Phase-3 candidates, not core.

**Done when:** navigation is practical, recovery is reliable, and the experience is clean enough
to put in front of a client.

## Floor Calibration

The initial calibration establishes the link between the real room and the virtual scene.

- The user aims the camera at the approximate floor and taps the spot (or places points) where the
  floor is. That tap becomes the **start position / origin**.
- **The virtual camera height must match the iPad's real height above that floor**, so the real and
  virtual worlds line up. Get this right and walking feels grounded; get it wrong and the scene
  sits too high or too low.

## Interaction Model

- **Physical movement (primary):** the camera moves, driven by the ARKit pose; the scene stays
  static. You walk the real room and move through the virtual one.
- **Teleport:** insert an **offset** between the raw ARKit pose and the rendered camera — move the
  scene / anchor, never overwrite the raw sensor pose. The user taps a target on the floor and
  appears there. **Reuse the AVP "Walkable" layer** to show where teleport is allowed; it may need
  changes for AR, since here you can also reach places by physically walking. The exact tap
  mechanic (plain tap, tap-and-hold, a gesture) is to be decided by testing.
- **Recovery:** reset / recenter to the start point or nearest hotspot. Required, not optional.
- **In-scene UI:** minimal edge HUD — main menu, reset / recenter, optional hotspot menu. Keep
  debug UI (FPS, frame time, memory) separate from the presentation HUD.

## Non-Goals for v1

Do not port the wider AVP feature set into the core: music player, HomePod interaction, audio
mixer, gesture-heavy HUD, oven clock, large onboarding video, tabletop / dollhouse AR, passthrough
object-placement AR, seamless scene transitions, and joystick / gamepad navigation. (Spatial audio
and similar feature ports are Phase-3 candidates, not core.)

## Key Technical Risks

- **Tracking loss** on a single camera with no passthrough cue → a recenter path is required.
  Drift itself is low-impact: nothing virtual is pinned to anything real and the real world is
  hidden, so there is no visible reference for the eye to catch small error.
- **Teleport** must be an offset, not a pose overwrite (see Interaction Model).
- **Flat-screen scale / immersion** is lower than the headset — this is judged as its own format,
  the pitch is portability.
- **Memory:** the AR session + camera buffers + OS consume part of the 4 GB before content; real
  headroom may be tighter than 2 GB — measure early, on a thin slice.
- **Thermal / battery** on a continuous AR session → possible throttling after extended demo use.

## Acceptance Criteria

The first serious version is a valid direction when it: installs and runs as a standalone iPad app;
calibrates reliably enough for demos; physical walking + rotation feel convincing; teleport + reset
make navigation practical; the chosen content slice looks sales-grade; and performance is stable on
iPad Air 4.

## First Technical Decision

When implementation starts, choose the rendering entry point: **`ARView`** (more samples for
"camera from ARKit pose", battle-tested) vs **`RealityView`** (iOS 18, closer to the AVP code
style). Lean `ARView` for speed; decide on the day.
