//
//  __SnapshotHarness.swift
//  UP_AR (UniPlace)
//
//  Developer-only preview harness. When the `UP_SNAPSHOT_VIEW` environment variable is set,
//  the app hosts a single chrome screen full-screen (over a faux camera backdrop) instead of
//  the real RootView, so the whole UI can be reviewed via `simctl io screenshot` without ARKit.
//
//  Drive it with Tools/snapshot.sh. Inert in normal launches (the env var is never set in
//  production). Remove this file and the `UP_SNAPSHOT_VIEW` branch in UP_ARApp to retire it.
//

import SwiftUI

enum SnapshotHarness {
    /// Every screen the harness can render, in review order. Keep names in sync with Tools/snapshot.sh.
    static let allViews = [
        "start", "start_floorpicker", "loading",
        "calibration", "calibration_found",
        "hud", "hud_locomotion", "hud_debug",
        "menu", "settings", "floorpicker", "help",
        "music",
        "gallery_video", "gallery_image",
    ]

    @MainActor @ViewBuilder
    static func liveView(named name: String) -> some View {
        switch name {
        case "start":              hosted(startModel()) { StartView() }
        case "start_floorpicker":  hosted(startModel(floorPicker: true)) { StartView() }
        case "loading":            hosted(baseModel()) { LoadingView() }
        case "calibration":        stage { CalibrationOverlay().environment(calibModel(found: false)) }
        case "calibration_found":  stage { CalibrationOverlay().environment(calibModel(found: true)) }
        case "hud":                stage { PresentationHUD().environment(baseModel()) }
        case "hud_locomotion":     stage { PresentationHUD().environment(model { $0.showLocomotionPanel = true }) }
        case "hud_debug":          stage { hudWithDebug(model { $0.showDebugOverlay = true; $0.fps = 60; $0.trackingStateLabel = "Normal"; $0.eyeHeight = 1.62; $0.heightNudge = 0.05 }) }
        case "menu":               stage { PresentationHUD().environment(model { $0.showMenu = true }) }
        case "settings":           stage { PresentationHUD().environment(model { $0.showSettings = true }) }
        case "floorpicker":        stage { PresentationHUD().environment(model { $0.showFloorPicker = true }) }
        case "help":               stage { PresentationHUD().environment(model { $0.showHelpPanel = true }) }
        case "music":              stage { PresentationHUD().environment(model { $0.showMusicPanel = true }) }
        case "gallery_video":      hosted(baseModel()) { FullscreenGalleryView(initialIndex: 0) }
        case "gallery_image":      hosted(baseModel()) { FullscreenGalleryView(initialIndex: 1) }
        default:                   stage { PresentationHUD().environment(baseModel()) }
        }
    }

    // MARK: - Hosting helpers

    /// Faux camera backdrop for screens that normally float over the live ARView.
    @MainActor @ViewBuilder
    private static func stage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            backdrop
            content()
        }
    }

    /// Screens that own their full background (Start, Loading, Gallery) just need the model injected.
    @MainActor @ViewBuilder
    private static func hosted<Content: View>(_ model: AppModel, @ViewBuilder _ content: () -> Content) -> some View {
        content().environment(model)
    }

    @MainActor @ViewBuilder
    private static func hudWithDebug(_ model: AppModel) -> some View {
        ZStack(alignment: .topLeading) {
            PresentationHUD()
            DebugOverlay().padding(16)
        }
        .environment(model)
    }

    private static var backdrop: some View {
        LinearGradient(
            colors: [Color(red: 0.28, green: 0.30, blue: 0.33), Color(red: 0.08, green: 0.09, blue: 0.11)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Model fixtures

    @MainActor
    private static func baseModel() -> AppModel {
        let m = AppModel()
        m.phase = .placed
        m.scenes = [.init(id: "floor7", title: "11th Floor"), .init(id: "terrace", title: "Terrace")]
        m.selectedSceneId = "floor7"
        m.musicAvailable = true
        m.musicIsPlaying = true
        m.musicTitle = "Midnight City"
        m.musicArtist = "M83"
        m.musicDuration = 244
        m.musicPosition = 73
        m.musicVolume = 0.62
        m.audioChannels = [
            .init(id: "music", title: "Music", systemImage: "music.note", volume: 0.62),
            .init(id: "fireplace", title: "Fireplace", systemImage: "flame", volume: 0.4),
            .init(id: "street", title: "Street", systemImage: "car", volume: 0.25),
        ]
        return m
    }

    /// `baseModel()` with an inline mutation, for one-off panel toggles.
    @MainActor
    private static func model(_ configure: (AppModel) -> Void) -> AppModel {
        let m = baseModel()
        configure(m)
        return m
    }

    @MainActor
    private static func startModel(floorPicker: Bool = false) -> AppModel {
        let m = baseModel()
        m.phase = .start
        m.showFloorPicker = floorPicker
        return m
    }

    @MainActor
    private static func calibModel(found: Bool) -> AppModel {
        let m = baseModel()
        m.phase = .calibrating
        m.floorDetected = found
        m.calibrationTitle = found ? "Floor found" : "Looking for the floor"
        m.lastMessage = found ? "Tap to place the apartment" : "Aim the center at the floor"
        return m
    }
}
