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
    func recenter()
    func recalibrate()
    func nudgeHeight(_ delta: Float)
}

@MainActor
@Observable
final class AppModel {
    /// One selectable scene shown on the start menu, sourced from the manifest (data-driven — no
    /// hardcoded scene names in the UI).
    struct SceneOption: Identifiable, Equatable {
        let id: String
        let title: String
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

    // Debug read-outs (written by the session delegate / display link, gated behind the overlay).
    var fps: Double = 0
    var trackingStateLabel = "—"
    var poseLabel = "—"

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
        selectedSceneId = id
        openVirtualCamera()
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

    func recenter() {
        actions?.recenter()
        lastMessage = "Recentered"
    }

    func recalibrate() {
        showMenu = false
        actions?.recalibrate()
    }

    func nudgeHeight(_ delta: Float) {
        actions?.nudgeHeight(delta)
    }
}
