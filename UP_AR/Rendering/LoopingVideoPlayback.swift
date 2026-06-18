//
//  LoopingVideoPlayback.swift
//  UP_AR (UniPlace)
//
//  A self-contained, seamlessly-looping muted video source for a RealityKit `VideoMaterial`.
//  Ported almost verbatim from the AVP fire path because that is where the video-decoder grief got
//  solved: an `AVQueuePlayer` + `AVPlayerLooper` (gap-free loop), muted, with stall-minimisation off
//  and a small forward buffer so the loop splice never micro-stutters. A keep-alive task plus a
//  `timeControlStatus` observer re-arm playback the instant anything (audio-session blips, OS pauses)
//  stops the player out from under us — without this the looping texture silently freezes.
//
//  Lifetime is owned by whatever holds this object (see FireVideoComponent): on release `deinit`
//  cancels the keep-alive and pauses the player, so a full scene teardown stops the decoder cleanly.
//

import AVFoundation
import RealityKit

final class LoopingVideoPlayback {
    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper
    private let templateItem: AVPlayerItem
    private var keepAliveTask: Task<Void, Never>?
    private var statusObservation: NSKeyValueObservation?
    private var errorObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var shouldBePlaying = false

    init(url: URL) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        // Keep a small forward buffer so the looping texture rides over the occasional underrun /
        // loop-splice hitch instead of micro-stalling. The clip is a short local file, so it is cheap.
        item.preferredForwardBufferDuration = 2

        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        self.player = player
        self.templateItem = item
        self.looper = AVPlayerLooper(player: player, templateItem: item)

        self.statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            switch item.status {
            case .readyToPlay:
                print("UP_AR fire video ready")
            case .failed:
                print("UP_AR fire video failed: \(item.error?.localizedDescription ?? "unknown error")")
            case .unknown:
                break
            @unknown default:
                break
            }
        }
        self.errorObservation = item.observe(\.error, options: [.new]) { item, _ in
            guard let error = item.error else { return }
            print("UP_AR fire video item error: \(error.localizedDescription)")
        }
        // Resume the instant the player is paused out from under us (e.g. a momentary audio-session
        // blip), instead of waiting up to a second for the keep-alive poll below.
        self.timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self, self.shouldBePlaying else { return }
            if player.timeControlStatus == .paused {
                player.play()
            }
        }
    }

    deinit {
        keepAliveTask?.cancel()
        player.pause()
    }

    /// Build the unlit video material. `writesDepth` defaults to false so the (alpha) fire composites
    /// over whatever is behind it rather than punching a hole in the depth buffer.
    func makeMaterial(writesDepth: Bool = false) -> VideoMaterial {
        var material = VideoMaterial(avPlayer: player)
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = writesDepth
        return material
    }

    func start() {
        shouldBePlaying = true
        play()
        guard keepAliveTask == nil else { return }

        keepAliveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.play()
                try? await Task.sleep(for: .milliseconds(1_000))
            }
        }
    }

    func stop() {
        shouldBePlaying = false
        keepAliveTask?.cancel()
        keepAliveTask = nil
        player.pause()
    }

    private func play() {
        guard player.timeControlStatus != .playing else { return }
        player.play()
    }
}
