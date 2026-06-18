//
//  RootView.swift
//  UP_AR (UniPlace)
//
//  Top-level view. Switches on the app phase and overlays the AR experience with the
//  appropriate SwiftUI layer (calibration prompt, presentation HUD, debug overlay).
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topLeading) {
            if appModel.phase == .start {
                // The menu is pure SwiftUI — shown instantly, with no ARView/ARKit warmup behind it.
                StartView()
            } else {
                if appModel.shouldWarmUpShell {
                    ARViewContainer()
                        .ignoresSafeArea()
                }

                if appModel.isShellReady {
                    switch appModel.phase {
                    case .start:       EmptyView()
                    case .calibrating: CalibrationOverlay()
                    case .loading:     LoadingView()
                    case .placed:      PresentationHUD()
                    }
                    if appModel.showDebugOverlay && appModel.phase == .placed {
                        DebugOverlay()
                            .padding(16)
                    }
                } else {
                    LoadingView()
                }
            }

            if appModel.showGallery {
                FullscreenGalleryView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            appModel.loadSceneCatalog()
        }
        // Duck spatial ambience the moment we leave the active state (before the engine is frozen on
        // background), so it ramps to silence instead of being cut mid-waveform and crackling.
        .onChange(of: scenePhase) { _, phase in
            appModel.setAudioBackgrounded(phase != .active)
        }
    }
}
