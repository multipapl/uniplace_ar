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
        switch appModel.phase {
        case .start:
            StartView()
        case .calibrating, .placed:
            ZStack {
                ARViewContainer()
                    .ignoresSafeArea()

                if appModel.phase == .calibrating {
                    CalibrationOverlay()
                } else {
                    PresentationHUD()
                }

                if appModel.showDebugOverlay {
                    DebugOverlay()
                }
            }
        }
    }
}
