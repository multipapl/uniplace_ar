//
//  PresentationHUD.swift
//  UP_AR (UniPlace)
//
//  Edge HUD for the placed experience.
//

import SwiftUI

struct PresentationHUD: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        ZStack {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    ChromeIconButton(systemName: "line.3.horizontal", title: "Menu", isSelected: appModel.showMenu) {
                        closeSecondaryPanels()
                        appModel.showMenu = true
                    }
                    Spacer()
                    if appModel.musicAvailable {
                        ChromeIconButton(systemName: "music.note", title: "Audio", isSelected: appModel.showMusicPanel) {
                            closeSecondaryPanels()
                            appModel.openMusicPanel()
                        }
                    }
                    ChromeIconButton(
                        systemName: "move.3d",
                        title: "Locomotion",
                        isSelected: appModel.showLocomotionPanel
                    ) {
                        appModel.showMenu = false
                        appModel.showMusicPanel = false
                        appModel.showFloorPicker = false
                        appModel.showSettings = false
                        appModel.showLocomotionPanel.toggle()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            if appModel.showLocomotionPanel {
                VStack {
                    Spacer()
                    LocomotionPanel()
                        .padding(.bottom, 92)
                }
            }

            if appModel.showMenu {
                RuntimeOverlay {
                    RuntimeMenuPanel()
                }
            }

            if appModel.showFloorPicker {
                RuntimeOverlay {
                    RuntimeFloorPickerPanel()
                }
            }

            if appModel.showSettings {
                RuntimeOverlay {
                    SettingsPanel()
                }
            }

            if appModel.showMusicPanel {
                RuntimeOverlay(alignment: .bottom) {
                    NowPlayingCard {
                        appModel.showMusicPanel = false
                    }
                    .frame(maxWidth: 520, maxHeight: 650)
                    .background(AppChrome.panelFill, in: RoundedRectangle(cornerRadius: AppChrome.panelRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppChrome.panelRadius)
                            .stroke(AppChrome.stroke, lineWidth: 1)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }
        }
    }

    private func closeSecondaryPanels() {
        appModel.showMenu = false
        appModel.showMusicPanel = false
        appModel.showFloorPicker = false
        appModel.showSettings = false
        appModel.showLocomotionPanel = false
    }
}

private struct RuntimeOverlay<Content: View>: View {
    @Environment(AppModel.self) private var appModel
    var alignment: Alignment = .center
    let content: Content

    init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: alignment) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

private struct RuntimeMenuPanel: View {
    @Environment(AppModel.self) private var appModel

    private var selectedSceneTitle: String {
        appModel.scenes.first { $0.id == appModel.selectedSceneId }?.title ?? "Scene"
    }

    var body: some View {
        ChromePanel {
            VStack(spacing: 18) {
                ChromeSheetHeader(title: "Menu", subtitle: selectedSceneTitle) {
                    appModel.showMenu = false
                }

                VStack(spacing: 10) {
                    ChromeCommandButton(title: "Open Level", systemName: "square.grid.2x2", isPrimary: true) {
                        appModel.showMenu = false
                        appModel.showFloorPicker = true
                    }
                    ChromePlainButton(title: "Settings", systemName: "gearshape") {
                        appModel.showMenu = false
                        appModel.showSettings = true
                    }
                    ChromePlainButton(title: "Main Menu", systemName: "house") {
                        appModel.returnToMainMenu()
                    }
                }

                Rectangle()
                    .fill(.black.opacity(0.10))
                    .frame(height: 1)

                Toggle("Debug overlay", isOn: Binding(
                    get: { appModel.showDebugOverlay },
                    set: { appModel.showDebugOverlay = $0 }
                ))
                .font(.system(size: 15, weight: .medium))
            }
        }
        .frame(maxWidth: AppChrome.maxPanelWidth)
        .padding(.horizontal, 18)
    }
}

private struct RuntimeFloorPickerPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ChromePanel {
            VStack(spacing: 18) {
                ChromeSheetHeader(title: "Open Level", subtitle: "Switch without recalibrating") {
                    appModel.showFloorPicker = false
                }

                VStack(spacing: 10) {
                    ForEach(appModel.scenes) { scene in
                        ChromePlainButton(
                            title: scene.title,
                            systemName: scene.id == "terrace" ? "sun.max" : "building",
                            isSelected: scene.id == appModel.selectedSceneId
                        ) {
                            appModel.showFloorPicker = false
                            appModel.switchScene(scene.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: AppChrome.maxPanelWidth)
        .padding(.horizontal, 18)
    }
}

private struct SettingsPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        ChromePanel {
            VStack(spacing: 18) {
                ChromeSheetHeader(title: "Settings", subtitle: "Session controls") {
                    appModel.showSettings = false
                }

                VStack(spacing: 14) {
                    Toggle("Debug overlay", isOn: $appModel.showDebugOverlay)
                    HStack {
                        Text("Floor offset")
                        Spacer()
                        Text(String(format: "%+.2f m", appModel.heightNudge))
                            .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.58))
                    }
                    HStack(spacing: 10) {
                        ChromePlainButton(title: "Lower", systemName: "arrow.down") {
                            appModel.nudgeHeight(-0.05)
                        }
                        ChromePlainButton(title: "Raise", systemName: "arrow.up") {
                            appModel.nudgeHeight(0.05)
                        }
                    }
                }
                .font(.system(size: 15, weight: .medium))
            }
        }
        .frame(maxWidth: AppChrome.maxPanelWidth)
        .padding(.horizontal, 18)
    }
}

private struct LocomotionPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ChromePanel {
            VStack(spacing: 8) {
                ChromeIconButton(systemName: "arrow.up", title: "Move Up", size: AppChrome.compactControlSize) {
                    appModel.nudgeHeight(0.05)
                }

                HStack(spacing: 8) {
                    ChromeIconButton(systemName: "rotate.left", title: "Turn Left", size: AppChrome.compactControlSize) {
                        appModel.snapTurnLeft()
                    }
                    ChromeIconButton(systemName: "scope", title: "Center", size: 52, isSelected: true) {
                        appModel.recenter()
                    }
                    ChromeIconButton(systemName: "rotate.right", title: "Turn Right", size: AppChrome.compactControlSize) {
                        appModel.snapTurnRight()
                    }
                }

                ChromeIconButton(systemName: "arrow.down", title: "Move Down", size: AppChrome.compactControlSize) {
                    appModel.nudgeHeight(-0.05)
                }
            }
        }
    }
}
