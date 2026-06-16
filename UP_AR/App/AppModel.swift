//
//  AppModel.swift
//  UP_AR (UniPlace)
//
//  Single source of truth for app flow and the values the UI/HUD display. Deliberately small:
//  AR/RealityKit work lives in the AR/ and Navigation/ modules and is reached via `actions`.
//

import Observation

/// Actions that need the live ARView / RealityKit scene. Implemented by `ARSessionController`,
/// so `AppModel` stays free of AR plumbing and only expresses intent + presentation state.
@MainActor
protocol ARExperienceActions: AnyObject {
    func recenter()
    func recalibrate()
    func nudgeHeight(_ delta: Float)
}

@MainActor
@Observable
final class AppModel {
    var phase: AppPhase = .start

    // Presentation read-outs.
    var eyeHeight: Float = 0       // device height above the calibrated floor (m)
    var heightNudge: Float = 0     // manual floor correction applied since calibration (m)
    var lastMessage: String = "Ready"

    // HUD / overlay toggles.
    var showMenu = false
    var showDebugOverlay = false

    // Debug read-outs (written by the session delegate / display link, gated behind the overlay).
    var fps: Double = 0
    var trackingStateLabel = "—"
    var poseLabel = "—"

    /// Delegate to the live AR experience. Weak to avoid a retain cycle with the controller.
    @ObservationIgnored weak var actions: ARExperienceActions?

    func openVirtualCamera() {
        phase = .calibrating
        lastMessage = "Aim at the floor and tap"
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
