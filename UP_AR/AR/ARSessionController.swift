//
//  ARSessionController.swift
//  UP_AR (UniPlace)
//
//  Owns the ARSession lifecycle, handles taps (calibrate / teleport), builds the scene hierarchy,
//  and feeds debug read-outs back into AppModel. Implements the AppModel → AR action delegate.
//

import RealityKit
import ARKit
import AVFoundation
import Combine
import QuartzCore
import UIKit

@MainActor
final class ARSessionController: NSObject, ARSessionDelegate, ARExperienceActions {
    private let appModel: AppModel
    private weak var arView: ARView?
    private var hierarchy: SceneHierarchy?
    private var calibrationPreviewAnchor: AnchorEntity?
    private var calibrationPreviewPlane: ModelEntity?
    private var teleportPreviewAnchor: AnchorEntity?
    private var teleportPreviewDisc: ModelEntity?
    /// Optional custom marker art (Assets catalog "TeleportMarker"), preloaded once. Absent ⇒ the
    /// procedural disc is used instead.
    private var teleportMarkerTexture: TextureResource?
    private var pendingTeleportTarget: SIMD3<Float>?
    private var latestCalibrationFloorTransform: simd_float4x4?
    private var calibrationStartedAt: CFTimeInterval = 0
    private var isPlacingScene = false
    private var isSessionRunning = false
    private var didLogFirstFrame = false
    private var didLogFirstFloorDetection = false
    /// The scene to load comes from the menu selection in AppModel — no hardcoded id here.
    private var levelProvider: LevelProvider {
        ManifestLevelProvider(sceneId: appModel.selectedSceneId, fallback: PlaceholderLevelProvider())
    }

    /// The in-scene HomePod player, built from the placed scene's `MusicEmitter`. Nil when the scene
    /// has no HomePod / no bundled tracks. The homepod root is kept for the tap-to-open gesture.
    private var musicController: SpatialMusicController?
    private var ambientController: AmbientSoundController?
    private weak var homepodEntity: Entity?
    /// The HomePod rim-glow shell (built by `HomepodProcessor`), faded in by viewer proximity each tick.
    private weak var homepodRimEntity: Entity?
    private var pressOnHomepod = false
    private var lastMusicReadout: CFTimeInterval = 0

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastFPSReadoutTimestamp: CFTimeInterval = 0
    private var lastCalibrationReadoutTimestamp: CFTimeInterval = 0
    private let calibrationPreviewDelay: CFTimeInterval = 0.9

    // Throttle for the (background-queue) frame read-outs, so we only hop to the main actor ~10/s.
    private nonisolated(unsafe) var lastReadoutHop: TimeInterval = 0

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
        appModel.actions = self
        configureAudioSession()
    }

    /// `.playback` so music keeps playing under the silent switch / in the background; `.mixWithOthers`
    /// so the muted looping video textures (fire, HomePod screen) don't pause each other. Set once.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print("UP_AR audio session config failed: \(error.localizedDescription)")
        }
    }

    func attach(to arView: ARView) {
        self.arView = arView
        PortalEnvironment.configure(arView)
        arView.session.delegate = self

        switch appModel.phase {
        case .start:
            PortalEnvironment.showPortalBackground(arView)
            startSession(resetTracking: true)
        case .calibrating:
            beginCalibration()
        case .loading, .placed:
            PortalEnvironment.showPortalBackground(arView)
            startSession(resetTracking: true)
        }

        // One press recogniser (zero delay) drives both phases: a quick press in calibration confirms
        // the floor on release; in the placed scene a press shows the teleport target, dragging moves
        // it, and releasing teleports there.
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress))
        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        arView.addGestureRecognizer(press)

        startDisplayLink()
    }

    private func startSession(resetTracking: Bool) {
        guard ARWorldTrackingConfiguration.isSupported else {
            appModel.lastMessage = "AR unavailable (simulator?) — tap to place the scene"
            appModel.finishShellWarmup()
            return
        }
        TimingDiagnostics.log("ARSession run begin")
        let options: ARSession.RunOptions = resetTracking
            ? [.resetTracking, .removeExistingAnchors]
            : []
        arView?.session.run(PortalEnvironment.makeConfiguration(),
                            options: options)
        isSessionRunning = true
        TimingDiagnostics.log("ARSession run returned")
    }

    func pause() {
        arView?.session.pause()
        isSessionRunning = false
        displayLink?.invalidate()
        displayLink = nil
        teardownSceneAudio()
    }

    // MARK: - Tap handling

    @objc private func handlePress(_ recognizer: UILongPressGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)
        switch appModel.phase {
        case .calibrating:
            if recognizer.state == .ended { confirmCalibration() }
        case .placed:
            switch recognizer.state {
            case .began:
                // A press that starts on the HomePod opens its music panel on release instead of
                // teleporting; anything else drives the teleport target as before.
                pressOnHomepod = homepodHit(at: point)
                if !pressOnHomepod { updateTeleportPreview(at: point) }
            case .changed:
                if !pressOnHomepod { updateTeleportPreview(at: point) }
            case .ended:
                if pressOnHomepod {
                    if appModel.musicAvailable { appModel.openMusicPanel() }
                    pressOnHomepod = false
                } else {
                    commitTeleport()
                }
            case .cancelled, .failed:
                pressOnHomepod = false
                removeTeleportPreview()
            default: break
            }
        case .start, .loading:
            break
        }
    }

    private func confirmCalibration() {
        guard let arView else { return }
        guard !isPlacingScene else { return }

        let floorTransform: simd_float4x4
        let eyeHeight: Float

        if let hit = currentCalibrationFloorTransform() {
            // Anchor the world under the user's feet, not under the aimed reticle. Take the detected
            // floor *height* from the reticle hit, but the *horizontal* position from the camera, so
            // the scene's spawn empty — which ManifestLevelProvider aligns to this origin — lands
            // exactly where the iPad physically stands when the level loads. The origin also carries a
            // yaw so the scene rotates about that point and the viewer faces the authored spawn
            // direction, regardless of which way the iPad physically points.
            let cam = arView.cameraTransform.translation
            let floorY = hit.columns.3.y
            let yaw = LocomotionController.spawnOriginYaw(cameraForward: cameraForward(arView),
                                                          spawnYawRadians: selectedSpawnYawRadians())
            var origin = simd_float4x4(simd_quatf(angle: yaw, axis: [0, 1, 0]))
            origin.columns.3 = SIMD4<Float>(cam.x, floorY, cam.z, 1)
            floorTransform = origin
            eyeHeight = cam.y - floorY
        } else if !ARWorldTrackingConfiguration.isSupported {
            // Simulator / no-AR fallback so the UI flow stays testable.
            floorTransform = matrix_identity_float4x4
            eyeHeight = 1.4
        } else {
            appModel.floorDetected = false
            removeCalibrationPreview()
            appModel.calibrationTitle = "Looking for the floor"
            appModel.lastMessage = "Floor not found yet"
            return
        }

        // Floor confirmed → switch to the loading screen and hide the passthrough feed. The scene is
        // revealed only once it is fully loaded AND has rendered (see placeScene) — no half-built pop-in.
        isPlacingScene = true
        appModel.phase = .loading
        removeCalibrationPreview()
        PortalEnvironment.showPortalBackground(arView)
        Task { await placeScene(floorTransform: floorTransform, eyeHeight: eyeHeight) }
    }

    private func placeScene(floorTransform: simd_float4x4, eyeHeight: Float) async {
        guard let arView else { return }
        defer { isPlacingScene = false }

        // On runtime scene switches, drop the old level and all audio before loading the new one.
        // This keeps memory from peaking with two apartments resident and cuts SFX during LoadingView.
        unloadCurrentScene()

        // All heavy loading happens here, behind the loading screen — never during calibration, where
        // it would steal cycles from ARKit and stutter the camera.
        let content: Entity
        do {
            content = try await levelProvider.makeContent()
        } catch {
            appModel.lastMessage = "Failed to load scene: \(error.localizedDescription)"
            appModel.phase = .calibrating
            return
        }
        let audioSettings = currentSceneAudioSettings()

        // Bind to a session-managed ARAnchor on device so ARKit keeps the floor pinned as it refines
        // its world map; fall back to a fixed world anchor where world tracking isn't available.
        let session: ARSession? = ARWorldTrackingConfiguration.isSupported ? arView.session : nil
        let newHierarchy = SceneHierarchy(floorTransform: floorTransform, content: content, session: session)
        arView.scene.addAnchor(newHierarchy.originAnchor)
        hierarchy = newHierarchy

        appModel.eyeHeight = eyeHeight
        appModel.heightNudge = 0
        appModel.floorDetected = false
        latestCalibrationFloorTransform = nil

        // Build scene audio before the reveal so ambient starts and the HUD's music affordance is ready
        // the moment the scene appears.
        setupSceneAudio(in: content, hierarchy: newHierarchy, settings: audioSettings)

        // Warm the optional teleport-marker texture once, well before the first teleport touch, so the
        // marker is built off a cached resource rather than loading mid-gesture.
        await preloadTeleportMarkerTexture()

        // Keep the loading screen up until the scene has actually rendered a few frames — this covers the
        // GPU texture-upload hitch on first display, so the reveal is clean rather than a stutter.
        await waitForSceneToRender(arView)

        appModel.phase = .placed
        appModel.lastMessage = "Walk, tap to teleport, or recenter"
        MemoryDiagnostics.log("scene placed")
    }

    /// Suspend until the scene has rendered `frames` updates, so the reveal lands after the first
    /// (hitchy) GPU upload rather than on top of it.
    private func waitForSceneToRender(_ arView: ARView, frames: Int = 3) async {
        await withCheckedContinuation { continuation in
            var remaining = frames
            var subscription: (any Cancellable)?
            subscription = arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
                remaining -= 1
                if remaining <= 0 {
                    subscription?.cancel()
                    continuation.resume()
                }
            }
        }
    }

    /// World point on the floor under a screen point, or nil when the ray misses the floor collider.
    private func floorTarget(at point: CGPoint) -> SIMD3<Float>? {
        guard let arView else { return nil }
        guard let hit = arView.hitTest(point, query: .nearest, mask: .all).first else { return nil }
        let world = hit.position
        return LocomotionController.isPlausibleTarget(world) ? world : nil
    }

    /// Show/move the teleport target marker while the finger is down. A miss keeps the last valid
    /// target so a small slip off the floor doesn't drop the pending destination.
    private func updateTeleportPreview(at point: CGPoint) {
        guard let arView, let target = floorTarget(at: point) else { return }
        pendingTeleportTarget = target

        let anchor: AnchorEntity
        if let teleportPreviewAnchor {
            anchor = teleportPreviewAnchor
        } else {
            anchor = AnchorEntity(world: matrix_identity_float4x4)
            teleportPreviewAnchor = anchor
            arView.scene.addAnchor(anchor)
        }
        // Lift the marker ~3 cm off the floor so it draws above rugs/carpets instead of z-fighting
        // under them.
        anchor.setPosition(target + SIMD3<Float>(0, 0.03, 0), relativeTo: nil)

        if teleportPreviewDisc == nil {
            let disc = makeTeleportPreviewDisc()
            teleportPreviewDisc = disc
            anchor.addChild(disc)
        }
        appModel.lastMessage = "Release to teleport"
    }

    /// On release: teleport to the marker if there is a valid target, then clear the marker.
    private func commitTeleport() {
        if let target = pendingTeleportTarget {
            performTeleport(toWorld: target)
        }
        removeTeleportPreview()
    }

    private func performTeleport(toWorld tappedWorld: SIMD3<Float>) {
        guard let arView, let hierarchy else { return }
        let cam = arView.cameraTransform.translation
        let floorY = hierarchy.originAnchor.position(relativeTo: nil).y
        let userGround = SIMD3<Float>(cam.x, floorY, cam.z)
        let shift = LocomotionController.teleportShift(userGround: userGround, tappedWorld: tappedWorld)
        hierarchy.applyTeleportShift(shift)
        appModel.lastMessage = "Teleported"
    }

    /// Load the optional custom marker texture from the asset catalog once. Missing asset is fine —
    /// the marker falls back to the procedural disc.
    private func preloadTeleportMarkerTexture() async {
        guard teleportMarkerTexture == nil else { return }
        // Decode via UIKit first: RealityKit's `TextureResource(named:)` fails to decode asset-catalog
        // images ("Image decoding failed"), but UIImage reads the catalog fine, and RealityKit ingests
        // the resulting CGImage without trouble. Absent/undecodable ⇒ the procedural disc is used.
        guard let cgImage = UIImage(named: "TeleportMarker")?.cgImage else { return }
        teleportMarkerTexture = try? await TextureResource(image: cgImage, options: .init(semantic: .color))
    }

    private func makeTeleportPreviewDisc() -> ModelEntity {
        let radius: Float = 0.4
        var material = UnlitMaterial(color: UIColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 0.5))
        material.faceCulling = .none

        let mesh: MeshResource
        if let texture = teleportMarkerTexture {
            // Custom art: the texture's own alpha gradient defines the silhouette and soft edge, so the
            // mesh is just a flat square and the tint stays white to show the art's colours unaltered.
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: 1.0)
            mesh = .generatePlane(width: radius * 2, depth: radius * 2)
        } else {
            // Fallback until a "TeleportMarker" image is added to the catalog: a procedural rounded disc.
            material.blending = .transparent(opacity: 0.5)
            mesh = .generatePlane(width: radius * 2, depth: radius * 2, cornerRadius: radius)
        }

        let disc = ModelEntity(mesh: mesh, materials: [material])
        disc.name = "TeleportPreview"
        addPulse(to: disc)
        return disc
    }

    /// Gentle looping scale pulse. It lives on the disc, which is a *child* of the anchor that follows
    /// the finger — so the per-touch position updates move the parent only and never re-touch this
    /// animation. That decoupling is what avoids the AVP flicker (there the marker entity itself was
    /// repositioned every frame, stepping on its own animation).
    private func addPulse(to disc: ModelEntity) {
        var small = disc.transform; small.scale = SIMD3<Float>(repeating: 0.9)
        var large = disc.transform; large.scale = SIMD3<Float>(repeating: 1.0)
        guard let pulse = try? AnimationResource.generate(with: FromToByAnimation(
            from: small, to: large, duration: 0.8, timing: .easeInOut,
            bindTarget: .transform, repeatMode: .autoReverse)) else { return }
        disc.playAnimation(pulse.repeat())
    }

    private func removeTeleportPreview() {
        if let teleportPreviewAnchor {
            arView?.scene.removeAnchor(teleportPreviewAnchor)
        }
        teleportPreviewAnchor = nil
        teleportPreviewDisc = nil
        pendingTeleportTarget = nil
    }

    // MARK: - ARExperienceActions

    func beginCalibration() {
        guard let arView else { return }
        removeCalibrationPreview()
        latestCalibrationFloorTransform = nil
        calibrationStartedAt = CACurrentMediaTime()
        isPlacingScene = false
        didLogFirstFrame = false
        didLogFirstFloorDetection = false
        lastCalibrationReadoutTimestamp = 0
        PortalEnvironment.showCalibrationFeed(arView)
        appModel.floorDetected = false
        appModel.calibrationTitle = "Preparing"
        appModel.lastMessage = "Stand at the start position"
        if !isSessionRunning {
            startSession(resetTracking: true)
        }
    }

    func returnToMainMenu() {
        unloadCurrentScene()
        removeTeleportPreview()
        removeCalibrationPreview()
        appModel.audioChannels = []
    }

    func reloadSelectedScene() {
        guard let hierarchy else {
            appModel.openVirtualCamera()
            return
        }
        let floorTransform = hierarchy.originAnchor.transformMatrix(relativeTo: nil)
        let eyeHeight = appModel.eyeHeight
        unloadCurrentScene()
        Task { await placeScene(floorTransform: floorTransform, eyeHeight: eyeHeight) }
    }

    func recenter() {
        hierarchy?.recenter()
    }

    func recalibrate() {
        unloadCurrentScene()
        appModel.phase = .calibrating
        beginCalibration()
    }

    func nudgeHeight(_ delta: Float) {
        hierarchy?.nudgeHeight(delta)
        appModel.heightNudge += delta
        appModel.eyeHeight -= delta   // raising the scene lowers the apparent eye height
    }

    func setRenderScale(_ scale: Double) {
        guard let arView else { return }
        let clamped = min(max(scale, AppModel.minRenderScale), AppModel.maxRenderScale)
        arView.contentScaleFactor = UIScreen.main.scale * clamped
        TimingDiagnostics.log(String(format: "render scale %.2f", clamped))
    }

    func setAudioBackgrounded(_ backgrounded: Bool) {
        if backgrounded {
            ambientController?.suspend()
        } else {
            ambientController?.resume()
        }
    }

    func snapTurn(_ degrees: Float) {
        guard let arView, let hierarchy else { return }
        let camera = arView.cameraTransform.translation
        let floorY = hierarchy.originAnchor.position(relativeTo: nil).y
        let pivot = SIMD3<Float>(camera.x, floorY, camera.z)
        hierarchy.rotateScene(degrees: degrees, aroundWorldPoint: pivot)
    }

    func musicTogglePlayPause() {
        musicController?.togglePlayPause()
        syncMusicState()
    }

    func musicNext() {
        musicController?.next()
        syncMusicState()
    }

    func musicPrevious() {
        musicController?.previous()
        syncMusicState()
    }

    func musicSetVolume(_ volume: Float) {
        musicController?.setVolume(volume)
    }

    func musicSeek(to seconds: TimeInterval) {
        musicController?.seek(to: seconds)
    }

    func musicSetShuffle(_ enabled: Bool) {
        musicController?.setShuffle(enabled)
        syncMusicState()
    }

    func setAudioChannelVolume(id: String, volume: Float) {
        let clamped = Self.clampUnit(volume)
        switch id {
        case "music":
            musicController?.setVolume(clamped)
            syncMusicState()
        case "rooftop":
            ambientController?.setRooftopVolume(clamped)
        default:
            ambientController?.setChannelVolume(id, clamped)
        }
    }

    // MARK: - Scene audio

    private struct SceneAudioSettings {
        let musicVolume: Float
        let ambient: AmbientSoundController.Configuration?
    }

    private func setupSceneAudio(in content: Entity, hierarchy: SceneHierarchy, settings: SceneAudioSettings) {
        setupAmbient(in: content, worldRoot: hierarchy.locomotionRoot, configuration: settings.ambient)
        setupMusic(in: content, environmentScale: settings.musicVolume)
        appModel.audioChannels = mixerChannels(for: settings)
    }

    private func teardownSceneAudio() {
        ambientController?.stop()
        ambientController = nil
        teardownMusic()
        appModel.audioChannels = []
    }

    private func unloadCurrentScene() {
        teardownSceneAudio()
        removeTeleportPreview()
        if let arView, let old = hierarchy {
            old.detachFromSession()
            arView.scene.removeAnchor(old.originAnchor)
        }
        hierarchy = nil
    }

    /// The camera's horizontal-ish forward (its −Z axis in world space) for spawn-facing alignment.
    private func cameraForward(_ arView: ARView) -> SIMD3<Float> {
        let z = arView.cameraTransform.matrix.columns.2
        return SIMD3<Float>(-z.x, -z.y, -z.z)
    }

    /// Authored spawn facing for the selected scene, in radians. Falls back to 0 (face scene −Z).
    private func selectedSpawnYawRadians() -> Float {
        guard let manifest = try? LevelResourceLocator().loadManifest(named: "LevelManifest"),
              let scene = manifest.scene(id: appModel.selectedSceneId) else { return 0 }
        return scene.spawn.yawRadians
    }

    private func currentSceneAudioSettings() -> SceneAudioSettings {
        guard let manifest = try? LevelResourceLocator().loadManifest(named: "LevelManifest"),
              let scene = manifest.scene(id: appModel.selectedSceneId) else {
            return SceneAudioSettings(musicVolume: 1, ambient: nil)
        }
        return SceneAudioSettings(
            musicVolume: Self.clampUnit(scene.musicVolume ?? 1),
            ambient: ambientConfiguration(for: scene, ambient: manifest.ambient)
        )
    }

    private func ambientConfiguration(
        for scene: LevelManifest.Scene,
        ambient: LevelManifest.Ambient?
    ) -> AmbientSoundController.Configuration? {
        guard let ambient else { return nil }
        let sources = (ambient.sources ?? [])
            .filter { ambientFloor($0.floor, appliesTo: scene.id) }
            .map {
                AmbientSoundController.Configuration.Source(
                    namePrefix: $0.namePrefix,
                    file: $0.file,
                    volume: appModel.savedAudioChannelVolume(
                        id: $0.namePrefix,
                        default: Self.clampUnit($0.volume ?? 1)
                    ),
                    attenuationRadius: max($0.attenuationRadius ?? 5, 0.1)
                )
            }
        let rooftopFile = ambientFloor("terrace", appliesTo: scene.id) ? ambient.rooftopFile : nil
        guard !sources.isEmpty || rooftopFile != nil else { return nil }
        return AmbientSoundController.Configuration(
            sources: sources,
            rooftopFile: rooftopFile,
            rooftopVolume: appModel.savedAudioChannelVolume(
                id: "rooftop",
                default: Self.clampUnit(ambient.rooftopVolume ?? 0.6)
            ),
            rooftopYawDegrees: ambient.rooftopYawDegrees ?? 0
        )
    }

    private func ambientFloor(_ floor: String?, appliesTo sceneId: String) -> Bool {
        let gate = (floor ?? "any").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch gate {
        case "", "any", "all":
            return true
        case "ground", "floor":
            return sceneId == "floor"
        case "terrace", "roof", "rooftop":
            return sceneId == "terrace"
        default:
            return gate == sceneId.lowercased()
        }
    }

    private func setupAmbient(
        in content: Entity,
        worldRoot: Entity,
        configuration: AmbientSoundController.Configuration?
    ) {
        guard let configuration else { return }
        let controller = AmbientSoundController(
            configuration: configuration,
            sceneRoot: content,
            worldRoot: worldRoot,
            locator: LevelResourceLocator()
        )
        ambientController = controller
        controller.start()
        MemoryDiagnostics.log("ambient ready")
    }

    private func mixerChannels(for settings: SceneAudioSettings) -> [AppModel.AudioChannel] {
        var channels: [AppModel.AudioChannel] = []
        if musicController != nil {
            channels.append(AppModel.AudioChannel(
                id: "music",
                title: "Music",
                systemImage: "music.note",
                volume: appModel.musicVolume
            ))
        }

        for source in settings.ambient?.sources ?? [] {
            channels.append(AppModel.AudioChannel(
                id: source.namePrefix,
                title: mixerTitle(for: source.namePrefix),
                systemImage: mixerIcon(for: source.namePrefix),
                volume: source.volume
            ))
        }
        if settings.ambient?.rooftopFile != nil {
            channels.append(AppModel.AudioChannel(
                id: "rooftop",
                title: "Rooftop",
                systemImage: "wind",
                volume: settings.ambient?.rooftopVolume ?? 0.6
            ))
        }
        return channels
    }

    private func mixerTitle(for namePrefix: String) -> String {
        namePrefix.replacingOccurrences(of: "SFX_", with: "")
    }

    private func mixerIcon(for namePrefix: String) -> String {
        let lowered = namePrefix.lowercased()
        if lowered.contains("fire") { return "flame" }
        if lowered.contains("water") { return "drop" }
        if lowered.contains("street") { return "building.2" }
        return "speaker.wave.2"
    }

    /// Build the HomePod player from the placed content: find the named `MusicEmitter` (placed by
    /// `HomepodProcessor`), read its tuning, and scan the bundled tracks. Inert when the scene has no
    /// HomePod or no tracks are bundled. Playback is manual — the user starts it from the panel.
    private func setupMusic(in content: Entity, environmentScale: Float) {
        guard let emitter = content.findEntity(named: "MusicEmitter"),
              let config = emitter.components[MusicEmitterComponent.self] else { return }

        let tracks = LevelResourceLocator().audioTrackURLs()
        guard !tracks.isEmpty else {
            TimingDiagnostics.log("homepod present but no bundled tracks in Content/Audio — music off")
            return
        }

        homepodEntity = homepodRoot(of: emitter)
        homepodRimEntity = homepodEntity?.findEntity(named: "HomepodRimShell")
        let controller = SpatialMusicController(
            emitter: emitter,
            tracks: tracks,
            shuffle: config.shuffle,
            volume: appModel.savedAudioChannelVolume(id: "music", default: config.defaultVolume),
            gainBoost: Audio.Decibel(config.gainBoostDB),
            reverb: musicReverb(preset: config.reverbPreset, levelDB: config.reverbLevelDB)
        )
        controller.setEnvironmentScale(environmentScale)
        musicController = controller
        appModel.musicAvailable = true
        // Warm the first track + audio engine now, behind the loading screen, so hitting play later is
        // instant instead of hitching the live experience.
        controller.prewarm()
        syncMusicState()
        MemoryDiagnostics.log("music ready (\(tracks.count) tracks)")
    }

    private func teardownMusic() {
        musicController?.stop()
        musicController = nil
        homepodEntity = nil
        homepodRimEntity = nil
        pressOnHomepod = false
        appModel.musicAvailable = false
        appModel.musicIsPlaying = false
        appModel.musicTitle = nil
        appModel.musicArtist = nil
        appModel.musicArtworkData = nil
        appModel.musicDuration = 0
        appModel.musicPosition = 0
        appModel.showMusicPanel = false
    }

    private static func clampUnit(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    /// Mirror the controller's published state onto AppModel for the now-playing card. Called after each
    /// control action and (with the playback position) periodically while the panel is open.
    private func syncMusicState() {
        guard let music = musicController else { return }
        appModel.musicIsPlaying = music.isPlaying
        appModel.musicTitle = music.currentTrackTitle
        appModel.musicArtist = music.currentTrackArtist
        appModel.musicArtworkData = music.currentArtworkData
        appModel.musicDuration = music.currentTrackDuration
        appModel.musicVolume = music.volume
        appModel.updateAudioChannelVolume(id: "music", volume: music.volume)
        appModel.musicShuffle = music.isShuffleEnabled
    }

    private func updateMusicReadout() {
        guard let music = musicController else { return }
        let now = CACurrentMediaTime()
        guard now - lastMusicReadout >= 0.25 else { return }
        lastMusicReadout = now
        appModel.musicPosition = music.currentPlaybackPosition
        syncMusicState()
    }

    /// Map a manifest reverb-preset name to a controller config, or nil to disable. A small subset is
    /// supported on purpose — the HomePod sits in a room, so the room-ish presets are what's useful.
    private func musicReverb(preset: String?, levelDB: Float) -> SpatialMusicController.ReverbConfiguration? {
        guard let name = preset?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !name.isEmpty, name != "none" else { return nil }
        let resolved: Reverb.Preset
        switch name {
        case "outside": resolved = .outside
        case "concerthall": resolved = .concertHall
        case "verylargeroom": resolved = .veryLargeRoom
        case "largeroom": resolved = .largeRoom
        case "mediumroom": resolved = .mediumRoomDry
        case "smallroom": resolved = .smallRoom
        default: resolved = .mediumRoomDry
        }
        return SpatialMusicController.ReverbConfiguration(preset: resolved, level: Audio.Decibel(levelDB))
    }

    /// Walk up from the emitter to the tagged HomePod layer root (for the tap-to-open gesture).
    private func homepodRoot(of entity: Entity) -> Entity? {
        var node: Entity? = entity
        while let current = node {
            if current.components.has(HomepodComponent.self) { return current }
            node = current.parent
        }
        return nil
    }

    /// True when the screen ray through `point` hits the HomePod's world bounding box. Uses the box
    /// (not a collider) so it never interferes with the floor raycast that teleport relies on.
    private func homepodHit(at point: CGPoint) -> Bool {
        guard appModel.musicAvailable, let arView, let homepod = homepodEntity else { return false }
        guard let ray = arView.ray(through: point) else { return false }
        let bounds = homepod.visualBounds(relativeTo: nil)
        return rayIntersectsBox(origin: ray.origin, direction: ray.direction, min: bounds.min, max: bounds.max)
    }

    private func rayIntersectsBox(origin: SIMD3<Float>, direction: SIMD3<Float>,
                                 min boxMin: SIMD3<Float>, max boxMax: SIMD3<Float>) -> Bool {
        var tMin: Float = 0
        var tMax: Float = .greatestFiniteMagnitude
        for axis in 0..<3 {
            let o = origin[axis], d = direction[axis]
            if abs(d) < 1e-6 {
                if o < boxMin[axis] || o > boxMax[axis] { return false }
            } else {
                let inv = 1 / d
                var t1 = (boxMin[axis] - o) * inv
                var t2 = (boxMax[axis] - o) * inv
                if t1 > t2 { swap(&t1, &t2) }
                tMin = Swift.max(tMin, t1)
                tMax = Swift.min(tMax, t2)
                if tMin > tMax { return false }
            }
        }
        return true
    }

    // MARK: - ARSessionDelegate (debug read-outs)

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
        Task { @MainActor [weak self] in
            guard let self, !didLogFirstFrame else { return }
            didLogFirstFrame = true
            TimingDiagnostics.log("first AR frame")
            appModel.finishShellWarmup()
        }

        guard timestamp - lastReadoutHop > 1.0 else { return }
        lastReadoutHop = timestamp

        let tracking = Self.label(for: frame.camera.trackingState)

        Task { @MainActor [weak self] in
            self?.consumeReadout(tracking: tracking)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.appModel.lastMessage = "AR error: \(message)"
        }
    }

    private func consumeReadout(tracking: String) {
        guard appModel.showDebugOverlay else { return }
        appModel.trackingStateLabel = tracking
    }

    nonisolated private static func label(for state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal: return "Normal"
        case .notAvailable: return "Not available"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Limited · initializing"
            case .excessiveMotion: return "Limited · excessive motion"
            case .insufficientFeatures: return "Limited · few features"
            case .relocalizing: return "Limited · relocalizing"
            @unknown default: return "Limited"
            }
        @unknown default: return "—"
        }
    }

    // MARK: - FPS (true render cadence)

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastFrameTimestamp = link.timestamp }
        updateCalibrationReadout()
        updateHomepodRim()
        if appModel.showMusicPanel { updateMusicReadout() }
        guard appModel.showDebugOverlay, lastFrameTimestamp != 0 else { return }
        guard link.timestamp - lastFPSReadoutTimestamp >= 1.0 else { return }
        lastFPSReadoutTimestamp = link.timestamp
        let dt = link.timestamp - lastFrameTimestamp
        if dt > 0 { appModel.fps = 1.0 / dt }
    }

    /// Fade the HomePod rim glow in as the viewer approaches: invisible beyond `far`, full by `near`.
    /// Runs every tick; the `OpacityComponent` set is cheap and only the shell (a small mesh) is touched.
    private func updateHomepodRim() {
        guard appModel.phase == .placed, let shell = homepodRimEntity, let arView else { return }
        let near: Float = 1.5   // full glow at/under this distance (m)
        let far: Float = 4.0    // fully faded out beyond this
        // Measure to the shell's VISUAL centre, not its transform origin: the HomePod body's origin sits
        // at the scene origin (Blender "Apply Location"), so `.position` would be metres off — the same
        // trap the MusicEmitter avoids by using the bounds centre.
        let target = shell.visualBounds(relativeTo: nil).center
        let distance = simd_distance(arView.cameraTransform.translation, target)
        let proximity = simd_clamp((far - distance) / (far - near), 0, 1)
        // ~2 s breathing pulse on top of the proximity fade (0.3…1.0, so it never blinks fully off).
        let period = 2.0
        let phase = CACurrentMediaTime().truncatingRemainder(dividingBy: period) / period * 2 * .pi
        let pulse = Float(0.65 + 0.35 * sin(phase))
        shell.components.set(OpacityComponent(opacity: proximity * pulse))
    }

    private func updateCalibrationReadout() {
        guard appModel.phase == .calibrating else { return }
        guard ARWorldTrackingConfiguration.isSupported else { return }
        guard arView != nil else { return }
        let now = CACurrentMediaTime()
        guard now - lastCalibrationReadoutTimestamp >= 0.2 else { return }
        lastCalibrationReadoutTimestamp = now

        let floorTransform = currentCalibrationFloorTransform()
        guard now - calibrationStartedAt >= calibrationPreviewDelay else {
            removeCalibrationPreview()
            if appModel.floorDetected {
                appModel.floorDetected = false
            }
            appModel.calibrationTitle = "Preparing"
            appModel.lastMessage = "Stand at the start position"
            return
        }

        let detected = floorTransform != nil
        if let floorTransform {
            if !didLogFirstFloorDetection {
                didLogFirstFloorDetection = true
                TimingDiagnostics.log("first floor detection")
            }
            updateCalibrationPreview(floorTransform)
        } else {
            removeCalibrationPreview()
        }
        guard detected != appModel.floorDetected else { return }

        appModel.floorDetected = detected
        appModel.calibrationTitle = detected
            ? "Floor found"
            : "Looking for the floor"
        appModel.lastMessage = detected
            ? "Tap to confirm start"
            : "Aim the center at the floor"
    }

    private func reticlePoint(in arView: ARView) -> CGPoint {
        CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    }

    private func currentCalibrationFloorTransform() -> simd_float4x4? {
        // The preview must always sit under the reticle (screen center) — that is what the user aims.
        // A direct reticle raycast hit is already under the reticle; the sampled points and plane
        // anchors only contribute the floor *height*, and we re-project the camera-forward ray onto
        // that height. We never fall back to an off-center sample or a plane center, which is what
        // used to make the grid slide sideways or behind the camera.
        if let hit = reticleFloorRaycast() {
            let flat = flattenedFloorTransform(at: hit.columns.3)
            latestCalibrationFloorTransform = flat
            return flat
        }
        if let floorY = fallbackFloorY(),
           let reticleTransform = transformAtReticle(floorY: floorY) {
            latestCalibrationFloorTransform = reticleTransform
            return reticleTransform
        }
        return latestCalibrationFloorTransform
    }

    /// Best available floor height when the reticle ray itself misses — never a full position.
    private func fallbackFloorY() -> Float? {
        if let sampled = sampledFloorRaycast() { return sampled.columns.3.y }
        if let plane = largestHorizontalPlaneTransform() { return plane.columns.3.y }
        return latestCalibrationFloorTransform?.columns.3.y
    }

    /// Gravity-aligned, axis-aligned floor transform at a world point (drops any inherited yaw so the
    /// preview grid stays flat and consistent instead of rotating with the detected plane).
    private func flattenedFloorTransform(at translation: SIMD4<Float>) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return transform
    }

    private func reticleFloorRaycast() -> simd_float4x4? {
        guard let arView else { return nil }
        let center = reticlePoint(in: arView)
        if let hit = floorRaycast(at: center, allowing: .existingPlaneGeometry) {
            return hit
        }
        return floorRaycast(at: center, allowing: .estimatedPlane)
    }

    private func sampledFloorRaycast() -> simd_float4x4? {
        guard let arView else { return nil }
        for point in calibrationSearchPoints(in: arView) {
            if let hit = floorRaycast(at: point, allowing: .existingPlaneGeometry) {
                return hit
            }
            if let hit = floorRaycast(at: point, allowing: .estimatedPlane) {
                return hit
            }
        }
        return nil
    }

    private func calibrationSearchPoints(in arView: ARView) -> [CGPoint] {
        let center = reticlePoint(in: arView)
        let bounds = arView.bounds
        guard bounds.width > 1, bounds.height > 1 else { return [center] }

        let offset = min(bounds.width, bounds.height) * 0.16
        return [
            center,
            CGPoint(x: center.x, y: center.y + offset),
            CGPoint(x: center.x - offset, y: center.y),
            CGPoint(x: center.x + offset, y: center.y),
            CGPoint(x: center.x, y: center.y - offset)
        ]
    }

    private func transformAtReticle(floorY: Float) -> simd_float4x4? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let cameraTransform = frame.camera.transform
        let origin = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let forward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        guard abs(forward.y) > 0.001 else { return nil }

        let distance = (floorY - origin.y) / forward.y
        guard distance > 0 else { return nil }

        let position = origin + forward * distance
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(position.x, floorY, position.z, 1)
        return transform
    }

    private func floorRaycast(at point: CGPoint,
                              allowing target: ARRaycastQuery.Target) -> simd_float4x4? {
        guard let arView else { return nil }
        guard let query = arView.makeRaycastQuery(from: point,
                                                  allowing: target,
                                                  alignment: .horizontal) else { return nil }
        return arView.session.raycast(query).first?.worldTransform
    }

    private func largestHorizontalPlaneTransform() -> simd_float4x4? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let plane = frame.anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { $0.alignment == .horizontal }
            .max { lhs, rhs in
                (lhs.planeExtent.width * lhs.planeExtent.height) <
                    (rhs.planeExtent.width * rhs.planeExtent.height)
            }

        guard let plane else { return nil }
        var transform = plane.transform
        let center = SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1)
        transform.columns.3 = plane.transform * center
        return transform
    }

    private func updateCalibrationPreview(_ floorTransform: simd_float4x4) {
        guard let arView else { return }

        let anchor: AnchorEntity
        if let calibrationPreviewAnchor {
            anchor = calibrationPreviewAnchor
            anchor.setTransformMatrix(floorTransform, relativeTo: nil)
        } else {
            anchor = AnchorEntity(world: floorTransform)
            calibrationPreviewAnchor = anchor
            arView.scene.addAnchor(anchor)
        }

        if calibrationPreviewPlane == nil {
            var material = UnlitMaterial(color: UIColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 0.14))
            material.blending = .transparent(opacity: 0.14)

            let plane = ModelEntity(mesh: .generatePlane(width: 1.45, depth: 1.45),
                                    materials: [material])
            plane.name = "CalibrationFloorPreview"
            plane.position.y = 0.002
            calibrationPreviewPlane = plane
            anchor.addChild(plane)
            addCalibrationPreviewDots(to: anchor)
        }
    }

    private func addCalibrationPreviewDots(to anchor: AnchorEntity) {
        var dotMaterial = UnlitMaterial(color: UIColor(red: 0.65, green: 1.0, blue: 1.0, alpha: 0.58))
        dotMaterial.blending = .transparent(opacity: 0.58)

        let dotSize: Float = 0.026
        let spacing: Float = 0.18
        let count = 7
        let origin = -Float(count - 1) * spacing / 2

        for row in 0..<count {
            for column in 0..<count {
                let dot = ModelEntity(mesh: .generatePlane(width: dotSize, depth: dotSize),
                                      materials: [dotMaterial])
                dot.name = "CalibrationFloorPreviewDot"
                dot.position = [
                    origin + Float(column) * spacing,
                    0.006,
                    origin + Float(row) * spacing
                ]
                anchor.addChild(dot)
            }
        }
    }

    private func removeCalibrationPreview() {
        guard let anchor = calibrationPreviewAnchor else { return }
        arView?.scene.removeAnchor(anchor)
        calibrationPreviewAnchor = nil
        calibrationPreviewPlane = nil
    }
}
