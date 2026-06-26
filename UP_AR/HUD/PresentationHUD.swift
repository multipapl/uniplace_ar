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
        GeometryReader { proxy in
            let isPhone = proxy.size.width < 600
            // While a modal panel is up, the top-right Help button is redundant and
            // (on phone, full-width panels) collides with the panel's own close button.
            let modalOpen = appModel.showHelpPanel || appModel.showMenu
                || appModel.showSettings || appModel.showFloorPicker || appModel.showMusicPanel

            ZStack {
                if !modalOpen {
                    VStack {
                        HStack {
                            Spacer()
                            ChromeIconButton(
                                systemName: "questionmark",
                                title: "Help",
                                isSelected: appModel.showHelpPanel
                            ) {
                                closeSecondaryPanels()
                                appModel.showHelpPanel = true
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)

                        Spacer()
                    }
                }

                if !(isPhone && appModel.showMusicPanel) {
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

                if appModel.showHelpPanel {
                    RuntimeOverlay {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()
                            .onTapGesture {
                                appModel.showHelpPanel = false
                            }
                        HelpPanel(maxContentHeight: isPhone ? proxy.size.height * 0.58 : 560)
                    }
                }

                if appModel.showMusicPanel {
                    RuntimeOverlay(alignment: .bottom) {
                        if isPhone {
                            Color.black.opacity(0.32)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    appModel.showMusicPanel = false
                                }
                        }
                        NowPlayingCard(compact: isPhone) {
                            appModel.showMusicPanel = false
                        }
                        .frame(maxWidth: isPhone ? .infinity : 520,
                               maxHeight: isPhone ? proxy.size.height * 0.72 : 650)
                        .background(AppChrome.panelFill, in: RoundedRectangle(cornerRadius: AppChrome.panelRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppChrome.panelRadius)
                                .stroke(AppChrome.stroke, lineWidth: 1)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, isPhone ? 12 : 16)
                        .padding(.bottom, isPhone ? 12 : 18)
                    }
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
        appModel.showHelpPanel = false
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
                    ChromePlainButton(title: "Gallery", systemName: "photo.on.rectangle") {
                        appModel.showMenu = false
                        appModel.showGallery = true
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Render scale")
                            Spacer()
                            Text("\(Int((appModel.renderScale * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundStyle(.black.opacity(0.58))
                        }
                        Slider(
                            value: Binding(
                                get: { appModel.renderScale },
                                set: { appModel.setRenderScale($0) }
                            ),
                            in: AppModel.minRenderScale...AppModel.maxRenderScale,
                            step: 0.05
                        )
                        HStack {
                            Text("Performance")
                            Spacer()
                            Text("Quality")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black.opacity(0.42))
                    }
                    .padding(12)
                    .background(AppChrome.controlFill, in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))

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
                    ChromePlainButton(title: "Reset Render Scale", systemName: "arrow.counterclockwise") {
                        appModel.resetRenderScale()
                    }
                }
                .font(.system(size: 15, weight: .medium))
            }
        }
        .frame(maxWidth: AppChrome.maxPanelWidth)
        .padding(.horizontal, 18)
    }
}

private struct HelpPanel: View {
    @Environment(AppModel.self) private var appModel
    var maxContentHeight: CGFloat = 560

    var body: some View {
        ChromePanel {
            VStack(spacing: 16) {
                ChromeSheetHeader(title: "Help", subtitle: "Runtime guide") {
                    appModel.showHelpPanel = false
                }

                ScrollView {
                    VStack(spacing: 14) {
                        HelpSection(
                            title: "Moving",
                            rows: [
                                .init(
                                    systemName: "viewfinder",
                                    title: "Calibration",
                                    detail: "Aim the center reticle at the real floor and press to confirm. The virtual apartment is placed under your feet from that floor point."
                                ),
                                .init(
                                    systemName: "figure.walk",
                                    title: "Physical walking",
                                    detail: "The camera feed is hidden. Move the iPad or iPhone through your real room to move through the virtual apartment."
                                ),
                                .init(
                                    systemName: "mappin.and.ellipse",
                                    title: "Teleport",
                                    detail: "Press and hold on a valid floor area to show the target disc, drag to adjust it, then release to move there."
                                ),
                                .init(
                                    systemName: "scope",
                                    title: "Recenter",
                                    detail: "Use the center button to return the scene pivot to the current viewing direction when the apartment feels offset."
                                ),
                                .init(
                                    systemName: "rotate.left",
                                    title: "Snap turn",
                                    detail: "Use left and right turn buttons for quick 45 degree rotations without physically turning."
                                ),
                                .init(
                                    systemName: "arrow.up.and.down",
                                    title: "Height nudge",
                                    detail: "Use the up and down buttons to fine tune the calibrated floor if the view feels too high or too low."
                                )
                            ]
                        )

                        HelpSection(
                            title: "Presentation",
                            rows: [
                                .init(
                                    systemName: "square.grid.2x2",
                                    title: "Open Level",
                                    detail: "Switch between the 11th Floor and Terrace without returning to calibration."
                                ),
                                .init(
                                    systemName: "photo.on.rectangle",
                                    title: "Gallery",
                                    detail: "Open stills and videos full screen. Use the eye button to hide the interface and leave only the media on screen."
                                ),
                                .init(
                                    systemName: "music.note",
                                    title: "Audio",
                                    detail: "Control the in-scene HomePod playlist, skip tracks, seek, shuffle, and adjust playback volume."
                                ),
                                .init(
                                    systemName: "slider.horizontal.3",
                                    title: "Sound mixer",
                                    detail: "When scene ambience is available, balance music, fireplace, water, street, and rooftop channels."
                                )
                            ]
                        )

                        HelpSection(
                            title: "Session",
                            rows: [
                                .init(
                                    systemName: "gearshape",
                                    title: "Settings",
                                    detail: "Open session controls, floor offset adjustment, and the debug overlay toggle."
                                ),
                                .init(
                                    systemName: "ladybug",
                                    title: "Debug overlay",
                                    detail: "Show FPS, tracking state, and pose readouts for device testing. Leave it off during presentations."
                                ),
                                .init(
                                    systemName: "arrow.counterclockwise",
                                    title: "Recalibrate",
                                    detail: "If tracking or floor alignment drifts, recalibrate from the runtime controls and tap the floor again."
                                ),
                                .init(
                                    systemName: "house",
                                    title: "Main Menu",
                                    detail: "Return to the start screen, stop the AR session, and choose another presentation entry point."
                                )
                            ]
                        )
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: maxContentHeight)

                ChromePlainButton(title: "Back", systemName: "chevron.left") {
                    appModel.showHelpPanel = false
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 18)
    }
}

private struct HelpSection: View {
    let title: String
    let rows: [HelpRow.Model]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChromeSectionLabel(title: title)
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    HelpRow(model: row)
                }
            }
        }
    }
}

private struct HelpRow: View {
    struct Model: Identifiable {
        let id = UUID()
        let systemName: String
        let title: String
        let detail: String
    }

    let model: Model

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppChrome.accent)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(model.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppChrome.controlFill, in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                .stroke(AppChrome.stroke, lineWidth: 1)
        }
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
