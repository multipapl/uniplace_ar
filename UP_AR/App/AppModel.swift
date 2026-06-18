//
//  AppModel.swift
//  UP_AR (UniPlace)
//
//  Single source of truth for app flow and the values the UI/HUD display. Deliberately small:
//  AR/RealityKit work lives in the AR/ and Navigation/ modules and is reached via `actions`.
//

import Foundation
import Observation

/// Actions that need the live ARView / RealityKit scene. Implemented by `ARSessionController`,
/// so `AppModel` stays free of AR plumbing and only expresses intent + presentation state.
@MainActor
protocol ARExperienceActions: AnyObject {
    func beginCalibration()
    func returnToMainMenu()
    func reloadSelectedScene()
    func recenter()
    func recalibrate()
    func nudgeHeight(_ delta: Float)
    func setRenderScale(_ scale: Double)
    func snapTurn(_ degrees: Float)

    /// Duck/restore spatial ambience around app backgrounding so the audio engine isn't interrupted
    /// mid-waveform (which crackles). Music keeps playing in the background, so it's untouched.
    func setAudioBackgrounded(_ backgrounded: Bool)

    // Spatial-music controls — they need the live scene's emitter, so they live behind this delegate
    // just like the calibration/teleport intents. The controller's state is mirrored back onto AppModel.
    func musicTogglePlayPause()
    func musicNext()
    func musicPrevious()
    func musicSetVolume(_ volume: Float)
    func musicSeek(to seconds: TimeInterval)
    func musicSetShuffle(_ enabled: Bool)
    func setAudioChannelVolume(id: String, volume: Float)
}

@MainActor
@Observable
final class AppModel {
    static let minRenderScale = 0.70
    static let maxRenderScale = 1.00
    private static let renderScaleDefaultsKey = "UP_AR.renderScale"
    private static let audioVolumeDefaultsPrefix = "UP_AR.audioVolume."

    /// One selectable scene shown on the start menu, sourced from the manifest (data-driven — no
    /// hardcoded scene names in the UI).
    struct SceneOption: Identifiable, Equatable {
        let id: String
        let title: String
    }

    /// One live audio mixer channel surfaced in the HomePod panel.
    struct AudioChannel: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
        var volume: Float
    }

    var phase: AppPhase = .start
    var shouldWarmUpShell = false
    var isShellReady = false

    /// Scenes offered on the start menu, and the one chosen for the next load.
    var scenes: [SceneOption] = []
    var selectedSceneId = ""

    // Presentation read-outs.
    var eyeHeight: Float = 0       // device height above the calibrated floor (m)
    var heightNudge: Float = 0     // manual floor correction applied since calibration (m)
    var lastMessage: String = "Ready"
    var calibrationTitle = "Looking for the floor"
    var floorDetected = false

    // HUD / overlay toggles.
    var showMenu = false
    var showDebugOverlay = false
    var showFloorPicker = false
    var showGallery = false
    var showSettings = false
    var showLocomotionPanel = false
    var showHelpPanel = false

    // Debug read-outs (written by the session delegate / display link, gated behind the overlay).
    var fps: Double = 0
    var trackingStateLabel = "—"
    var poseLabel = "—"
    var renderScale: Double = AppModel.loadRenderScale()

    // Music (the in-scene HomePod player). Presentation state mirrored from the controller by the AR
    // session; controls are expressed as intent through `actions`. AppModel holds no audio/RealityKit.
    var musicAvailable = false
    var musicIsPlaying = false
    var musicTitle: String?
    var musicArtist: String?
    var musicArtworkData: Data?
    var musicDuration: TimeInterval = 0
    var musicPosition: TimeInterval = 0
    var musicVolume: Float = 0.6
    var musicShuffle = false
    var showMusicPanel = false
    var audioChannels: [AudioChannel] = []

    /// Delegate to the live AR experience. Weak to avoid a retain cycle with the controller.
    @ObservationIgnored weak var actions: ARExperienceActions?

    /// Read the manifest's scene list (cheap JSON only — no asset loading) for the start menu.
    func loadSceneCatalog() {
        guard scenes.isEmpty else { return }
        guard let manifest = try? LevelResourceLocator().loadManifest(named: "LevelManifest") else {
            TimingDiagnostics.log("scene catalog unavailable")
            return
        }
        scenes = manifest.scenes.map { SceneOption(id: $0.id, title: $0.title) }
    }

    func beginShellWarmup() {
        guard !shouldWarmUpShell else { return }
        lastMessage = "Loading"
        DispatchQueue.main.async { [weak self] in
            self?.shouldWarmUpShell = true
        }
    }

    func finishShellWarmup() {
        guard !isShellReady else { return }
        isShellReady = true
        lastMessage = "Ready"
        TimingDiagnostics.log("shell ready")
    }

    /// Pick a scene on the start menu, then enter calibration. The AR session is only spun up here —
    /// never at launch — so the menu appears instantly and nothing heavy runs before it.
    func selectScene(_ id: String) {
        showFloorPicker = false
        selectedSceneId = id
        openVirtualCamera()
    }

    func switchScene(_ id: String) {
        guard id != selectedSceneId else {
            showFloorPicker = false
            showMenu = false
            return
        }
        selectedSceneId = id
        showFloorPicker = false
        showMenu = false
        showMusicPanel = false
        showLocomotionPanel = false
        showHelpPanel = false
        lastMessage = "Loading"
        if phase == .placed || phase == .loading {
            phase = .loading
            DispatchQueue.main.async { [weak self] in
                self?.actions?.reloadSelectedScene()
            }
        } else {
            openVirtualCamera()
        }
    }

    func openVirtualCamera() {
        TimingDiagnostics.log("open virtual camera tapped (scene: \(selectedSceneId))")
        phase = .calibrating
        floorDetected = false
        calibrationTitle = "Preparing"
        lastMessage = "Aim the center at the floor"
        beginShellWarmup()           // spin up the ARView/session now, not at launch
        actions?.beginCalibration()  // no-op until the ARView mounts; attach() re-runs it
    }

    func returnToMainMenu() {
        showMenu = false
        showMusicPanel = false
        showFloorPicker = false
        showGallery = false
        showSettings = false
        showLocomotionPanel = false
        showHelpPanel = false
        showDebugOverlay = false
        floorDetected = false
        calibrationTitle = "Looking for the floor"
        lastMessage = "Ready"
        audioChannels = []
        actions?.returnToMainMenu()
        phase = .start
        shouldWarmUpShell = false
        isShellReady = false
    }

    func recenter() {
        showLocomotionPanel = false
        actions?.recenter()
        lastMessage = "Recentered"
    }

    func recalibrate() {
        showMenu = false
        showLocomotionPanel = false
        showHelpPanel = false
        actions?.recalibrate()
    }

    func nudgeHeight(_ delta: Float) {
        actions?.nudgeHeight(delta)
    }

    func setRenderScale(_ value: Double) {
        renderScale = Self.clampRenderScale(value)
        UserDefaults.standard.set(renderScale, forKey: Self.renderScaleDefaultsKey)
        actions?.setRenderScale(renderScale)
    }

    func resetRenderScale() {
        setRenderScale(Self.maxRenderScale)
    }

    func setAudioBackgrounded(_ backgrounded: Bool) {
        actions?.setAudioBackgrounded(backgrounded)
    }

    func snapTurnLeft() {
        actions?.snapTurn(45)
        lastMessage = "Turned left 45°"
    }

    func snapTurnRight() {
        actions?.snapTurn(-45)
        lastMessage = "Turned right 45°"
    }

    // MARK: Music intents (forwarded to the live controller via `actions`)

    func openMusicPanel() { showMusicPanel = true }
    func closeMusicPanel() { showMusicPanel = false }

    func musicTogglePlayPause() { actions?.musicTogglePlayPause() }
    func musicNext() { actions?.musicNext() }
    func musicPrevious() { actions?.musicPrevious() }

    func setMusicVolume(_ value: Float) {
        musicVolume = Self.clampUnit(value)
        saveAudioChannelVolume(id: "music", volume: musicVolume)
        updateAudioChannelVolume(id: "music", volume: musicVolume)
        actions?.musicSetVolume(musicVolume)
    }

    func seekMusic(to seconds: TimeInterval) {
        musicPosition = seconds
        actions?.musicSeek(to: seconds)
    }

    func setMusicShuffle(_ enabled: Bool) {
        musicShuffle = enabled
        actions?.musicSetShuffle(enabled)
    }

    func setAudioChannelVolume(id: String, _ value: Float) {
        let clamped = Self.clampUnit(value)
        saveAudioChannelVolume(id: id, volume: clamped)
        updateAudioChannelVolume(id: id, volume: clamped)
        if id == "music" {
            musicVolume = clamped
        }
        actions?.setAudioChannelVolume(id: id, volume: clamped)
    }

    func updateAudioChannelVolume(id: String, volume: Float) {
        guard let index = audioChannels.firstIndex(where: { $0.id == id }) else { return }
        audioChannels[index].volume = Self.clampUnit(volume)
    }

    func savedAudioChannelVolume(id: String, default defaultValue: Float) -> Float {
        let key = Self.audioVolumeDefaultsKey(id: id)
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return Self.clampUnit(defaultValue)
        }
        return Self.clampUnit(Float(UserDefaults.standard.double(forKey: key)))
    }

    private static func loadRenderScale() -> Double {
        guard UserDefaults.standard.object(forKey: renderScaleDefaultsKey) != nil else {
            return maxRenderScale
        }
        return clampRenderScale(UserDefaults.standard.double(forKey: renderScaleDefaultsKey))
    }

    private static func clampRenderScale(_ value: Double) -> Double {
        min(max(value, minRenderScale), maxRenderScale)
    }

    private func saveAudioChannelVolume(id: String, volume: Float) {
        UserDefaults.standard.set(Double(Self.clampUnit(volume)), forKey: Self.audioVolumeDefaultsKey(id: id))
    }

    private static func audioVolumeDefaultsKey(id: String) -> String {
        audioVolumeDefaultsPrefix + id
    }

    private static func clampUnit(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
