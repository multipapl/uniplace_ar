//
//  NowPlayingCard.swift
//  UP_AR (UniPlace)
//
//  HomePod music player plus live scene-audio mixer.
//

import SwiftUI

struct NowPlayingCard: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    var closeAction: (() -> Void)?

    @State private var selectedTab: AudioTab = .player
    @State private var scrubbing = false
    @State private var scrubValue: TimeInterval = 0

    fileprivate enum AudioTab: String, CaseIterable, Identifiable {
        case player = "Player"
        case mixer = "Mixer"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            ChromeSheetHeader(title: "Audio", subtitle: "HomePod") {
                if let closeAction {
                    closeAction()
                } else {
                    dismiss()
                }
            }

            AudioTabBar(selectedTab: $selectedTab)

            ScrollView {
                switch selectedTab {
                case .player:
                    player
                case .mixer:
                    mixer
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(22)
        .presentationDragIndicator(.visible)
    }

    private var player: some View {
        VStack(spacing: 18) {
            artwork
            trackLabels
            scrubber
            transport
            volumeControls
        }
        .padding(.top, 4)
    }

    private var artwork: some View {
        Group {
            if let data = appModel.musicArtworkData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.secondary.opacity(0.22), .secondary.opacity(0.08)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.42))
                }
            }
        }
        .frame(width: 184, height: 184)
        .clipShape(RoundedRectangle(cornerRadius: AppChrome.panelRadius))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                Circle()
                    .fill(appModel.musicIsPlaying ? Color.green : .white.opacity(0.42))
                    .frame(width: 7, height: 7)
                Text(appModel.musicIsPlaying ? "PLAYING" : "PAUSED")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: AppChrome.panelRadius))
            .padding(8)
        }
    }

    private var trackLabels: some View {
        VStack(spacing: 5) {
            Text(appModel.musicTitle ?? "Not Playing")
                .font(.system(size: 21, weight: .semibold))
                .lineLimit(1)
            Text(appModel.musicArtist ?? "HomePod")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.56))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubbing ? scrubValue : appModel.musicPosition },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(appModel.musicDuration, 0.01),
                onEditingChanged: { editing in
                    if editing {
                        scrubbing = true
                        scrubValue = appModel.musicPosition
                    } else {
                        appModel.seekMusic(to: scrubValue)
                        scrubbing = false
                    }
                }
            )
            .disabled(appModel.musicDuration <= 0)
            HStack {
                Text(Self.timeLabel(scrubbing ? scrubValue : appModel.musicPosition))
                Spacer()
                Text(Self.timeLabel(appModel.musicDuration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.black.opacity(0.52))
        }
    }

    private var transport: some View {
        HStack(spacing: 16) {
            TransportButton(systemName: "backward.fill", size: 46) {
                appModel.musicPrevious()
            }
            TransportButton(systemName: appModel.musicIsPlaying ? "pause.fill" : "play.fill", size: 66, isPrimary: true) {
                appModel.musicTogglePlayPause()
            }
            TransportButton(systemName: "forward.fill", size: 46) {
                appModel.musicNext()
            }
        }
    }

    private var volumeControls: some View {
        VStack(spacing: 10) {
            ChromeSectionLabel(title: "Volume", value: "\(Int((appModel.musicVolume * 100).rounded()))")
            HStack(spacing: 12) {
                Button {
                    appModel.setMusicShuffle(!appModel.musicShuffle)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(appModel.musicShuffle ? .black : .black.opacity(0.58))
                        .frame(width: 34, height: 34)
                        .background(appModel.musicShuffle ? AppChrome.warmAccent : .black.opacity(0.07), in: Circle())
                }
                .buttonStyle(ChromePressButtonStyle())

                Image(systemName: "speaker.fill").foregroundStyle(.black.opacity(0.42))
                Slider(
                    value: Binding(
                        get: { Double(appModel.musicVolume) },
                        set: { appModel.setMusicVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.black.opacity(0.42))
            }
            .font(.title3)
            .padding(12)
            .background(AppChrome.controlFill, in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
        }
    }

    private var mixer: some View {
        VStack(spacing: 14) {
            ChromeSectionLabel(title: "Scene mixer")
            if appModel.audioChannels.isEmpty {
                ChromeEmptyState(
                    systemName: "slider.horizontal.3",
                    title: "Mixer unavailable",
                    subtitle: "No live audio channels are active in this scene."
                )
            } else {
                ForEach(appModel.audioChannels) { channel in
                    MixerRow(channel: channel)
                }
            }
        }
        .padding(.top, 4)
    }

    private static func timeLabel(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.towardZero))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct AudioTabBar: View {
    @Binding var selectedTab: NowPlayingCard.AudioTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(NowPlayingCard.AudioTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(selectedTab == tab ? .white : .black.opacity(0.58))
                        .background(selectedTab == tab ? .black : .clear,
                                    in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
                }
                .buttonStyle(ChromePressButtonStyle())
            }
        }
        .padding(4)
        .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
    }
}

private struct TransportButton: View {
    let systemName: String
    var size: CGFloat
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 25 : 17, weight: .bold))
                .foregroundStyle(isPrimary ? .white : .black)
                .frame(width: size, height: size)
                .background(isPrimary ? .black : .black.opacity(0.07), in: Circle())
                .overlay {
                    Circle().stroke(.black.opacity(isPrimary ? 0.70 : 0.10), lineWidth: 1)
                }
        }
        .buttonStyle(ChromePressButtonStyle())
    }
}

private struct MixerRow: View {
    @Environment(AppModel.self) private var appModel
    let channel: AppModel.AudioChannel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: channel.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppChrome.accent)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.07), in: Circle())
                Text(channel.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int((channel.volume * 100).rounded()))")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black.opacity(0.58))
                    .frame(width: 38, alignment: .trailing)
            }

            Slider(
                value: Binding(
                    get: { Double(channel.volume) },
                    set: { appModel.setAudioChannelVolume(id: channel.id, Float($0)) }
                ),
                in: 0...1
            )
        }
        .padding(13)
        .background(AppChrome.controlFill, in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        }
    }
}
