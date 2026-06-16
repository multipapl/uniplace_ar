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
            if appModel.shouldWarmUpShell {
                ARViewContainer()
                    .ignoresSafeArea()
            }

            if appModel.isShellReady {
                switch appModel.phase {
                case .start:
                    StartView()
                case .calibrating:
                    CalibrationOverlay()
                case .placed:
                    PresentationHUD()
                }

                if appModel.phase != .start {
                    if appModel.showDebugOverlay {
                        DebugOverlay()
                    }
                }
            } else {
                LoadingView()
            }
        }
        .onAppear {
            appModel.beginShellWarmup()
        }
    }
}
