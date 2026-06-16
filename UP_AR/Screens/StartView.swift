//
//  StartView.swift
//  UP_AR (UniPlace)
//
//  Start screen: a single entry point into the virtual camera (per the brief / Enviz tile pattern).
//

import SwiftUI

struct StartView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack {
            BlurredCoverBackground(imageName: "main_menu")

            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text("UniPlace")
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Virtual walkthrough")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button {
                    appModel.openVirtualCamera()
                } label: {
                    Label("Open Virtual Camera", systemImage: "arkit")
                        .font(.headline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 28)
                        .frame(maxWidth: 420)
                        .background(.white, in: .capsule)
                        .foregroundStyle(.black)
                }
                .padding(.bottom, 60)
            }
            .padding()
        }
    }
}
