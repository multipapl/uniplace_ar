//
//  NowPlayingCard.swift
//  UP_AR (UniPlace)
//
//  The HomePod music player, surfaced as a SwiftUI sheet from the HUD (or a tap on the HomePod). Binds
//  to the music read-outs on AppModel and expresses control as intent through it — it never touches the
//  audio controller (that lives in the AR session). Mixer (per-channel SFX/rooftop levels) is a later
//  step; this is music-only.
//

import SwiftUI

struct NowPlayingCard: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    /// While the user drags the scrubber, show their position instead of the periodic playback read-out
    /// so the thumb doesn't fight the ~4 Hz updates.
    @State private var scrubbing = false
    @State private var scrubValue: TimeInterval = 0

    var body: some View {
        VStack(spacing: 18) {
            header
            artwork
            trackLabels
            scrubber
            transport
            footer
        }
        .padding(24)
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("HomePod")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var artwork: some View {
        Group {
            if let data = appModel.musicArtworkData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 160, height: 160)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var trackLabels: some View {
        VStack(spacing: 4) {
            Text(appModel.musicTitle ?? "Not playing")
                .font(.headline)
                .lineLimit(1)
            Text(appModel.musicArtist ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 2) {
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
            .foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 36) {
            Button { appModel.musicPrevious() } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            Button { appModel.musicTogglePlayPause() } label: {
                Image(systemName: appModel.musicIsPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            Button { appModel.musicNext() } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
        }
        .foregroundStyle(.primary)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                appModel.setMusicShuffle(!appModel.musicShuffle)
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(appModel.musicShuffle ? Color.accentColor : .secondary)
            }
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(appModel.musicVolume) },
                    set: { appModel.setMusicVolume(Float($0)) }
                ),
                in: 0...1
            )
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .font(.title3)
    }

    private static func timeLabel(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.towardZero))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
