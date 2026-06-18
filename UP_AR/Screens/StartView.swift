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
        @Bindable var appModel = appModel
        GeometryReader { proxy in
            let isPhone = proxy.size.width < 600

            ZStack {
                BlurredCoverBackground(imageName: "main_menu", blurRadius: 3, dimOpacity: 0.42)

                VStack(spacing: isPhone ? 20 : 28) {
                    Spacer(minLength: isPhone ? 24 : 0)
                    VStack(spacing: 10) {
                        Text("UniPlace")
                            .font(.system(size: isPhone ? 46 : 60, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Virtual walkthrough")
                            .font(.system(size: isPhone ? 16 : 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    Spacer(minLength: isPhone ? 18 : 0)
                    ChromePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            ChromeSectionLabel(title: "Presentation")
                            ChromeCommandButton(title: "Select Floor", systemName: "square.grid.2x2", isPrimary: true) {
                                appModel.showFloorPicker = true
                            }
                            .disabled(appModel.scenes.isEmpty)

                            ChromePlainButton(title: "Gallery", systemName: "photo.on.rectangle") {
                                appModel.showGallery = true
                            }
                        }
                    }
                    .frame(maxWidth: AppChrome.maxPanelWidth)
                    .padding(.bottom, isPhone ? 24 : 60)
                }
                .padding(.horizontal, isPhone ? 16 : 22)

                if appModel.showFloorPicker {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .onTapGesture {
                            appModel.showFloorPicker = false
                        }
                    FloorPickerPanel()
                        .frame(maxWidth: AppChrome.maxPanelWidth)
                        .padding(.horizontal, isPhone ? 16 : 22)
                        .offset(y: isPhone ? 0 : 118)
                }
            }
        }
    }
}

private struct FloorPickerPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ChromePanel {
            VStack(spacing: 18) {
                ChromeSheetHeader(title: "Select Floor", subtitle: "Choose the scene to open") {
                    appModel.showFloorPicker = false
                }

                VStack(spacing: 10) {
                    ForEach(appModel.scenes) { scene in
                        ChromePlainButton(
                            title: scene.title,
                            systemName: scene.id == "terrace" ? "sun.max" : "building",
                            isSelected: false
                        ) {
                            appModel.showFloorPicker = false
                            appModel.selectScene(scene.id)
                        }
                    }
                    if appModel.scenes.isEmpty {
                        ChromeEmptyState(
                            systemName: "exclamationmark.triangle",
                            title: "No scenes available",
                            subtitle: "The scene catalog could not be loaded."
                        )
                    }
                }
            }
        }
    }
}
