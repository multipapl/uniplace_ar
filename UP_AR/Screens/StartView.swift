//
//  StartView.swift
//  UP_AR (UniPlace)
//
//  Start screen: a single entry point into the virtual camera (per the brief / Enviz tile pattern).
//

import AVKit
import SwiftUI

struct StartView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        ZStack {
            BlurredCoverBackground(imageName: "main_menu", blurRadius: 3, dimOpacity: 0.42)

            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 10) {
                    Text("UniPlace")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Virtual walkthrough")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
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
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 22)

            if appModel.showFloorPicker {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appModel.showFloorPicker = false
                    }
                FloorPickerPanel()
                    .frame(maxWidth: AppChrome.maxPanelWidth)
                    .padding(.horizontal, 22)
                    .offset(y: 118)
            }
        }
        .sheet(isPresented: $appModel.showGallery) {
            MainGalleryView()
                .presentationDetents([.large])
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

private struct MainGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items = GalleryLibrary.items()
    @State private var selectedIndex = 0

    private var selectedItem: GalleryMediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 16) {
            ChromeSheetHeader(
                title: "Gallery",
                subtitle: items.isEmpty ? "Presentation media" : "\(items.count) items"
            ) {
                dismiss()
            }

            if let selectedItem {
                GalleryStage(item: selectedItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                GalleryFilmstrip(items: items, selectedIndex: $selectedIndex)
                    .frame(height: 92)
            } else {
                ChromePanel {
                    ChromeEmptyState(
                        systemName: "photo.on.rectangle.angled",
                        title: "Gallery is empty",
                        subtitle: "Photos and videos will appear here when the gallery content is added."
                    )
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(22)
        .presentationDragIndicator(.visible)
        .onAppear {
            items = GalleryLibrary.items()
            selectedIndex = min(selectedIndex, max(items.count - 1, 0))
        }
    }
}

private struct GalleryStage: View {
    let item: GalleryMediaItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppChrome.panelRadius)
                .fill(.black)

            switch item.kind {
            case .image:
                GalleryImageView(url: item.url, contentMode: .fit)
                    .padding(10)
            case .video:
                GalleryVideoView(url: item.url)
                    .padding(10)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Label(item.title, systemImage: item.kind == .video ? "play.rectangle" : "photo")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
                .padding(16)
        }
    }
}

private struct GalleryFilmstrip: View {
    let items: [GalleryMediaItem]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selectedIndex = index
                    } label: {
                        GalleryThumbnail(item: item, isSelected: index == selectedIndex)
                    }
                    .buttonStyle(ChromePressButtonStyle())
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct GalleryThumbnail: View {
    let item: GalleryMediaItem
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                .fill(.black.opacity(0.86))

            switch item.kind {
            case .image:
                GalleryImageView(url: item.url, contentMode: .fill)
            case .video:
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 126, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: AppChrome.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                .stroke(isSelected ? .black : .black.opacity(0.14), lineWidth: isSelected ? 3 : 1)
        }
    }
}

private struct GalleryImageView: View {
    enum ContentMode {
        case fit
        case fill
    }

    let url: URL
    let contentMode: ContentMode
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                let rendered = Image(uiImage: image)
                    .resizable()
                switch contentMode {
                case .fit:
                    rendered.scaledToFit()
                case .fill:
                    rendered.scaledToFill()
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .clipped()
        .task(id: url) {
            image = UIImage(contentsOfFile: url.path)
        }
    }
}

private struct GalleryVideoView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppChrome.panelRadius))
        .task(id: url) {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
