//
//  FullscreenGalleryView.swift
//  UP_AR (UniPlace)
//
//  Full-screen presentation gallery for bundled stills and videos.
//

import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct FullscreenGalleryView: View {
    /// Item to open on first appearance (deep-link / preview entry point).
    var initialIndex = 0
    @Environment(AppModel.self) private var appModel
    @State private var items = GalleryLibrary.items()
    @State private var selectedIndex = 0
    @State private var chromeVisible = true
    @State private var slideEdge: Edge = .trailing

    private var selectedItem: GalleryMediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let selectedItem {
                // Keyed by index so paging swaps identity and slides; the controls-free
                // video view (see GalleryVideoView) lets taps/swipes through, so a tap
                // always toggles the chrome and there's no way to get stuck.
                GalleryStage(item: selectedItem, showTitle: chromeVisible)
                    .id(selectedIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideEdge),
                        removal: .move(edge: slideEdge == .trailing ? .leading : .trailing)
                    ).combined(with: .opacity))
                    .ignoresSafeArea(edges: chromeVisible ? [] : .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            chromeVisible.toggle()
                        }
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                if value.translation.width <= -40 {
                                    paginate(by: 1)
                                } else if value.translation.width >= 40 {
                                    paginate(by: -1)
                                }
                            }
                    )

                if chromeVisible {
                    galleryChrome(selectedItem: selectedItem)
                        .transition(.opacity)
                }
            } else {
                GalleryEmptyFullscreen {
                    appModel.showGallery = false
                }
            }
        }
        .statusBarHidden(!chromeVisible)
        .persistentSystemOverlays(chromeVisible ? .automatic : .hidden)
        .onAppear {
            items = GalleryLibrary.items()
            selectedIndex = min(max(initialIndex, 0), max(items.count - 1, 0))
        }
    }

    /// Move the selection by `delta`, clamped, sliding in the matching direction.
    private func paginate(by delta: Int) {
        let target = selectedIndex + delta
        guard items.indices.contains(target) else { return }
        select(target)
    }

    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        slideEdge = index > selectedIndex ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.28)) {
            selectedIndex = index
        }
    }

    private func galleryChrome(selectedItem: GalleryMediaItem) -> some View {
        VStack(spacing: 0) {
            GalleryTopBar(
                title: selectedItem.title,
                subtitle: "\(selectedIndex + 1) / \(items.count)",
                hideInterface: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        chromeVisible = false
                    }
                },
                close: {
                    appModel.showGallery = false
                }
            )
            .padding(.horizontal, 18)
            .padding(.top, 12)

            Spacer()

            GalleryFilmstrip(items: items, selectedIndex: selectedIndex, onSelect: select)
                .frame(height: 96)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
        }
    }
}

private struct GalleryTopBar: View {
    let title: String
    let subtitle: String
    let hideInterface: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ChromeIconButton(systemName: "chevron.left", title: "Back", action: close)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .monospacedDigit()
            }

            Spacer()

            ChromeIconButton(systemName: "eye.slash", title: "Hide Interface", action: hideInterface)
        }
    }
}

private struct GalleryStage: View {
    let item: GalleryMediaItem
    let showTitle: Bool

    var body: some View {
        ZStack {
            Color.black

            switch item.kind {
            case .image:
                GalleryImageView(url: item.url, contentMode: .fit)
                    .padding(showTitle ? 18 : 0)
            case .video:
                GalleryVideoView(url: item.url)
                    .padding(showTitle ? 18 : 0)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showTitle {
                Label(item.title, systemImage: item.kind == .video ? "play.rectangle" : "photo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
                    .padding(.leading, 20)
                    .padding(.bottom, 118)
            }
        }
    }
}

private struct GalleryFilmstrip: View {
    let items: [GalleryMediaItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onSelect(index)
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
            Rectangle()
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
                .stroke(isSelected ? .white : .white.opacity(0.20), lineWidth: isSelected ? 3 : 1)
        }
    }
}

private struct GalleryEmptyFullscreen: View {
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ChromeEmptyState(
                systemName: "photo.on.rectangle.angled",
                title: "Gallery is empty",
                subtitle: "Photos and videos will appear here when the gallery content is added."
            )
            ChromePlainButton(title: "Back", systemName: "chevron.left", action: close)
        }
        .padding(22)
        .frame(maxWidth: AppChrome.maxPanelWidth)
        .background(AppChrome.panelFill, in: RoundedRectangle(cornerRadius: AppChrome.panelRadius))
        .foregroundStyle(.black)
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

/// Looping, controls-free video. Native `VideoPlayer` chrome (with its volume button) used to
/// swallow taps, trapping the user when the gallery interface was hidden — this renders straight
/// into an AVPlayerLayer so taps and swipes reach the gallery's own gestures.
private struct GalleryVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        uiView.load(url: url)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var loadedURL: URL?

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        load(url: url)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(url: URL) {
        guard url != loadedURL else { return }
        loadedURL = url
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        playerLayer.player = queue
        queuePlayer = queue
        queue.play()
    }

    func stop() {
        queuePlayer?.pause()
        queuePlayer = nil
        looper = nil
        playerLayer.player = nil
    }
}
