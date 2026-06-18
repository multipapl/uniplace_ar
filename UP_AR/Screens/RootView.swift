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

    var body: some View {
        ZStack {
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
                    }
                } else {
                    LoadingView()
                }
            }
        }
        .onAppear {
            appModel.loadSceneCatalog()
        }
    }
}
