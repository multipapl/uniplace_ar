//
//  SpatialMusicController.swift
//  UP_AR (UniPlace)
//
//  Ported from the AVP fire/audio lineage. Plays a playlist of tracks as spatial audio emitted from a
//  fixed entity in the scene (the in-scene HomePod body). Owns playlist order, shuffle, user volume,
//  manual playback controls, and per-track loading.
//
//  `volume` is the user's target level from the HUD / HomePod controls.
//
//  Tracks are loaded lazily, one at a time. RealityKit audio resources load into memory with no lazy
//  disk streaming, so only the current track is kept resident; the previous controller and resource are
//  released before the next track loads.
//

import AVFoundation
import Foundation
import RealityKit

@MainActor
@Observable
final class SpatialMusicController {
    struct TrackMetadata {
        let title: String
        let artist: String?
        let duration: TimeInterval
        let artworkData: Data?
    }

    struct ReverbConfiguration {
        let preset: Reverb.Preset
        let level: Audio.Decibel
    }

    private(set) var isPlaying = false
    private(set) var currentTrackTitle: String?
    private(set) var currentTrackArtist: String?
    private(set) var currentTrackDuration: TimeInterval = 0
    private(set) var currentArtworkData: Data?
    private(set) var volume: Float
    private(set) var isShuffleEnabled: Bool

    @ObservationIgnored private let emitter: Entity
    @ObservationIgnored private let gainBoost: Audio.Decibel
    @ObservationIgnored private let tracks: [URL]
    @ObservationIgnored private var order: [Int] = []
    @ObservationIgnored private var cursor = 0
    @ObservationIgnored private var controller: AudioPlaybackController?
    @ObservationIgnored private var reverbEntity: Entity?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var shouldBePlaying = false
    @ObservationIgnored private var consecutiveLoadFailures = 0
    /// Per-scene loudness multiplier applied on top of the user volume (1 = full). Used to limit the
    /// HomePod music on the terrace the way AVP ducks it by altitude — UP_AR loads scenes separately,
    /// so the duck is a fixed per-scene scale set once at setup rather than a live altitude crossfade.
    @ObservationIgnored private var environmentScale: Float = 1

    /// Silence floor. Below this a track is effectively inaudible; we fade to here instead of -inf so
    /// the engine always has a finite target.
    private let silenceFloorDB: Audio.Decibel = -60
    private let volumeFadeDuration: TimeInterval = 0.15

    init(
        emitter: Entity,
        tracks: [URL],
        shuffle: Bool,
        volume: Float,
        gainBoost: Audio.Decibel = 0,
        reverb: ReverbConfiguration? = nil
    ) {
        self.emitter = emitter
        self.gainBoost = gainBoost
        self.tracks = tracks
        self.isShuffleEnabled = shuffle
        self.volume = Self.clampUnit(volume)

        // The emitter must carry a spatial component so playback is positioned and distance-attenuated.
        // Leave its gain neutral (0 dB) - the audible level is driven entirely through the playback
        // controller below.
        if let reverb {
            emitter.components.set(SpatialAudioComponent(reverbLevel: reverb.level))

            let reverbEntity = Entity()
            reverbEntity.name = "MusicReverb"
            reverbEntity.components.set(ReverbComponent(reverb: .preset(reverb.preset)))
            emitter.addChild(reverbEntity)
            self.reverbEntity = reverbEntity
        } else {
            emitter.components.set(SpatialAudioComponent())
        }
    }

    // MARK: Lifecycle

    /// Start, or resume, playback. Idempotent. The first call builds the play order and loads the first
    /// track; later calls resume the current track if it was paused.
    func start() {
        guard !tracks.isEmpty else { return }
        activateAudioSession()
        shouldBePlaying = true
        if let controller {
            controller.play()
            isPlaying = true
            return
        }
        guard loadTask == nil else { return }
        rebuildOrder(keepingCurrent: false)
        loadAndPlayCurrent()
    }

    /// Decode and prepare the first track *without* playing, so the heavy first-load (file decode +
    /// audio-engine spin-up) is paid behind the loading screen rather than as a hitch the moment the
    /// user hits play mid-experience. A later `start()`/`resume()` just plays the warmed controller.
    func prewarm() {
        guard !tracks.isEmpty, controller == nil, loadTask == nil else { return }
        activateAudioSession()
        rebuildOrder(keepingCurrent: false)
        loadAndPlayCurrent(autoPlay: false)
    }

    /// Stop playback and release the current track resource.
    func stop() {
        shouldBePlaying = false
        loadTask?.cancel()
        loadTask = nil
        controller?.stop()
        controller = nil
        isPlaying = false
    }

    // MARK: HUD controls

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        stop()
    }

    func resume() {
        activateAudioSession()
        shouldBePlaying = true
        guard let controller else {
            start()
            return
        }
        controller.play()
        isPlaying = true
    }

    func next() {
        advance(by: 1)
    }

    func previous() {
        advance(by: -1)
    }

    func setVolume(_ value: Float) {
        volume = Self.clampUnit(value)
        controller?.fade(to: currentGainDB, duration: volumeFadeDuration)
    }

    /// Set the per-scene loudness scale (1 = full). Applied on top of the user volume.
    func setEnvironmentScale(_ scale: Float) {
        let clamped = Self.clampUnit(scale)
        guard abs(clamped - environmentScale) > 0.001 else { return }
        environmentScale = clamped
        controller?.fade(to: currentGainDB, duration: 0.25)
    }

    func setShuffle(_ enabled: Bool) {
        guard enabled != isShuffleEnabled else { return }
        isShuffleEnabled = enabled
        rebuildOrder(keepingCurrent: true)
    }

    var currentPlaybackPosition: TimeInterval {
        guard let controller else { return 0 }
        return min(max(controller.__playbackPosition, 0), currentTrackDuration)
    }

    func seek(to seconds: TimeInterval) {
        guard let controller, currentTrackDuration > 0 else { return }
        let clamped = min(max(seconds, 0), currentTrackDuration)
        controller.seek(to: Self.duration(from: clamped))
    }

    // MARK: Internals

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("UP_AR music audio session activate failed: \(error.localizedDescription)")
        }
    }

    private func advance(by step: Int) {
        guard !tracks.isEmpty else { return }
        activateAudioSession()
        if order.isEmpty { rebuildOrder(keepingCurrent: false) }
        cursor = (cursor + step + order.count) % order.count
        loadAndPlayCurrent()
    }

    private func handleTrackCompletion() {
        guard !tracks.isEmpty else { return }
        cursor += 1
        if cursor >= order.count {
            // Wrapped past the end: reshuffle (avoiding an immediate repeat of the last track) and
            // restart from the top.
            rebuildOrder(keepingCurrent: false)
            cursor = 0
        }
        loadAndPlayCurrent()
    }

    private func loadAndPlayCurrent(autoPlay: Bool = true) {
        guard order.indices.contains(cursor) else { return }
        let url = tracks[order[cursor]]

        controller?.stop()
        controller = nil
        loadTask?.cancel()
        currentTrackTitle = url.deletingPathExtension().lastPathComponent
        currentTrackArtist = nil
        currentTrackDuration = 0
        currentArtworkData = nil

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let metadata = await Self.loadTrackMetadata(for: url)
                let resource = try await AudioFileResource(contentsOf: url)
                guard !Task.isCancelled else { return }

                let controller = self.emitter.prepareAudio(resource)
                controller.gain = self.currentGainDB
                controller.completionHandler = { [weak self] in
                    Task { @MainActor in self?.handleTrackCompletion() }
                }
                self.controller = controller
                if autoPlay {
                    controller.play()
                    self.isPlaying = true
                } else {
                    self.isPlaying = false
                }
                self.currentTrackTitle = metadata.title
                self.currentTrackArtist = metadata.artist
                self.currentTrackDuration = metadata.duration
                self.currentArtworkData = metadata.artworkData
                self.consecutiveLoadFailures = 0
                self.loadTask = nil
            } catch {
                guard !Task.isCancelled else { return }
                print("UP_AR music load failed for \(url.lastPathComponent): \(error.localizedDescription)")
                self.loadTask = nil
                self.consecutiveLoadFailures += 1
                // Skip the bad track, but give up once every track has failed so we don't spin forever.
                if self.consecutiveLoadFailures < self.tracks.count {
                    self.handleTrackCompletion()
                } else {
                    self.isPlaying = false
                    self.currentTrackTitle = nil
                    self.currentTrackArtist = nil
                    self.currentTrackDuration = 0
                    self.currentArtworkData = nil
                }
            }
        }
    }

    private func rebuildOrder(keepingCurrent: Bool) {
        let indices = Array(tracks.indices)
        let previousTrack = order.indices.contains(cursor) ? order[cursor] : nil

        guard isShuffleEnabled, indices.count > 1 else {
            order = indices
            cursor = keepingCurrent ? (previousTrack ?? 0) : 0
            return
        }

        var shuffled = indices.shuffled()
        // Don't open the new order on the track that's currently playing.
        if let previousTrack, shuffled.first == previousTrack {
            shuffled.swapAt(0, shuffled.count - 1)
        }
        order = shuffled

        if keepingCurrent, let previousTrack, let idx = shuffled.firstIndex(of: previousTrack) {
            cursor = idx
        } else {
            cursor = 0
        }
    }

    private var currentGainDB: Audio.Decibel {
        // Below the silence floor when fully muted; otherwise the user level (scaled per scene) in dB
        // plus the fixed calibration boost that compensates for the emitter's distance attenuation.
        let linear = Self.clampUnit(volume) * Self.clampUnit(environmentScale)
        guard linear > 0.0001 else { return silenceFloorDB }
        return max(Audio.Decibel(20 * log10(Double(linear))) + gainBoost, silenceFloorDB)
    }

    private static func clampUnit(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    nonisolated private static func loadTrackMetadata(for url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        let duration: TimeInterval
        do {
            let cmDuration = try await asset.load(.duration)
            duration = cmDuration.seconds.isFinite ? cmDuration.seconds : 0
        } catch {
            duration = 0
        }

        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        let title = await metadata.firstString(for: .commonIdentifierTitle) ?? fallbackTitle
        let artist = await metadata.firstString(for: .commonIdentifierArtist)
        var artworkData = await metadata.firstData(for: .commonIdentifierArtwork)
        if artworkData == nil {
            artworkData = await Self.loadID3ArtworkData(from: asset)
        }

        return TrackMetadata(
            title: title,
            artist: artist,
            duration: duration,
            artworkData: artworkData
        )
    }

    nonisolated private static func loadID3ArtworkData(from asset: AVURLAsset) async -> Data? {
        guard let formats = try? await asset.load(.availableMetadataFormats),
              formats.contains(.id3Metadata),
              let metadata = try? await asset.loadMetadata(for: .id3Metadata) else {
            return nil
        }

        return await metadata.firstData(rawIdentifier: "id3/APIC", key: "APIC")
    }

    private static func duration(from seconds: TimeInterval) -> Duration {
        let wholeSeconds = Int64(seconds.rounded(.towardZero))
        let fractional = seconds - TimeInterval(wholeSeconds)
        let attoseconds = Int64((fractional * 1_000_000_000_000_000_000).rounded())
        return Duration(secondsComponent: wholeSeconds, attosecondsComponent: attoseconds)
    }
}

private extension Array where Element == AVMetadataItem {
    nonisolated func firstString(for identifier: AVMetadataIdentifier) async -> String? {
        for item in self where item.identifier == identifier {
            let value = try? await item.load(.stringValue)
            if let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return normalized
            }
        }
        return nil
    }

    nonisolated func firstData(for identifier: AVMetadataIdentifier) async -> Data? {
        for item in self where item.identifier == identifier {
            if let value = try? await item.load(.dataValue) {
                return value
            }
        }
        return nil
    }

    nonisolated func firstData(rawIdentifier: String, key: String) async -> Data? {
        for item in self {
            let matchesIdentifier = item.identifier?.rawValue == rawIdentifier
            let matchesKey = (item.key as? String) == key
            guard matchesIdentifier || matchesKey else { continue }

            if let value = try? await item.load(.dataValue) {
                return value
            }
        }
        return nil
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
