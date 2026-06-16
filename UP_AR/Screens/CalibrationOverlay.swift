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

            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(appModel.floorDetected ? "Підлогу знайдено" : "Шукаю підлогу")
                        .font(.headline)
                    Text(appModel.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.black.opacity(0.55), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(markerColor.opacity(0.7), lineWidth: 1)
                }
                .padding(.bottom, 80)
            }
        }
        .allowsHitTesting(false)
    }
}
