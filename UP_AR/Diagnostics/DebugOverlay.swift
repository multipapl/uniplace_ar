//
//  DebugOverlay.swift
//  UP_AR (UniPlace)
//
//  Developer-facing read-outs, kept entirely separate from the presentation HUD. Toggled from the
//  HUD menu. Lets taps through so it never interferes with teleport/recenter.
//

import SwiftUI

struct DebugOverlay: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "FPS    %.0f", appModel.fps))
            Text("Track  \(appModel.trackingStateLabel)")
            Text(String(format: "Eye    %.2f m", appModel.eyeHeight))
            Text(String(format: "Nudge  %+.2f m", appModel.heightNudge))
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.green)
        .padding(10)
        .background(.black.opacity(0.72), in: .rect(cornerRadius: 8))
        .fixedSize()
        .allowsHitTesting(false)
    }
}
