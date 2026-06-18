//
//  CalibrationOverlay.swift
//  UP_AR (UniPlace)
//
//  Shown while aiming at the floor: a center reticle + a prompt. The tap itself is handled by the
//  ARView gesture (see ARSessionController); this layer is presentation only and lets taps through.
//

import SwiftUI

struct CalibrationOverlay: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let markerColor = appModel.floorDetected ? Color.cyan : Color.white

        ZStack {
            ZStack {
                Circle()
                    .stroke(markerColor.opacity(0.95), lineWidth: 2)
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(markerColor.opacity(0.55), lineWidth: 1)
                    .frame(width: 82, height: 82)
                Rectangle()
                    .fill(markerColor.opacity(0.9))
                    .frame(width: 22, height: 2)
                Rectangle()
                    .fill(markerColor.opacity(0.9))
                    .frame(width: 2, height: 22)
                Circle()
                    .fill(markerColor)
                    .frame(width: 6, height: 6)
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()

                HStack {
                    ChromeIconButton(systemName: "chevron.left", title: "Main Menu") {
                        appModel.returnToMainMenu()
                    }

                    Spacer()

                    ChromeIconButton(systemName: "arrow.counterclockwise", title: "Recalibrate") {
                        appModel.recalibrate()
                    }
                }
                .padding(.bottom, 22)
                .padding(.horizontal, 20)
            }

            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(appModel.calibrationTitle)
                        .font(.system(size: 17, weight: .semibold))
                    Text(appModel.lastMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 22)
                .background(.black.opacity(0.52), in: .rect(cornerRadius: AppChrome.panelRadius))
                .overlay(RoundedRectangle(cornerRadius: AppChrome.panelRadius).stroke(markerColor.opacity(0.55), lineWidth: 1))
                .padding(.bottom, 96)
            }
            .allowsHitTesting(false)
        }
    }
}
