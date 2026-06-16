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
        ZStack {
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 44, height: 44)
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)

            VStack {
                Spacer()
                Text(appModel.lastMessage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(.bottom, 80)
            }
        }
        .allowsHitTesting(false)
    }
}
