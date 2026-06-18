//
//  PresentationHUD.swift
//  UP_AR (UniPlace)
//
//  Minimal edge HUD for the placed experience: recenter + a menu (recalibrate, floor-height nudge,
//  debug toggle). Presentation-grade only — no FPS/memory here (that lives in DebugOverlay).
//

import SwiftUI

struct PresentationHUD: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            HStack {
                Button {
                    appModel.showMenu.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal").hudIcon()
                }
                Spacer()
                if appModel.musicAvailable {
                    Button {
                        appModel.openMusicPanel()
                    } label: {
                        Image(systemName: "music.note").hudIcon()
                    }
                }
                Button {
                    appModel.recenter()
                } label: {
                    Image(systemName: "scope").hudIcon()
                }
            }
            .padding()
            Spacer()
        }
        .sheet(isPresented: $appModel.showMenu) {
            MenuSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $appModel.showMusicPanel) {
            NowPlayingCard()
                .presentationDetents([.medium])
        }
    }
}

private struct MenuSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack {
            List {
                Section("Floor height") {
                    HStack {
                        Button("Lower") { appModel.nudgeHeight(-0.05) }
                        Spacer()
                        Text(String(format: "%+.2f m", appModel.heightNudge))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Raise") { appModel.nudgeHeight(0.05) }
                    }
                    .buttonStyle(.bordered)
                }
                Section {
                    Button("Recenter") { appModel.recenter() }
                    Button("Recalibrate floor") { appModel.recalibrate() }
                }
                Section {
                    Toggle("Debug overlay", isOn: $appModel.showDebugOverlay)
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

private extension Image {
    func hudIcon() -> some View {
        self
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.black.opacity(0.5), in: .circle)
    }
}
