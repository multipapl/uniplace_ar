//
//  AmbientSoundController.swift
//  UP_AR (UniPlace)
//
//  The environmental sound layer that plays alongside the HomePod music. Ported from the AVP ambient
//  path, trimmed to UP_AR's two-scene model: there is no listener-altitude crossfade or floor gating
//  here (those assume one continuous space; UP_AR loads floor and terrace as separate scenes), so each
//  scene simply plays its ambient set at full volume.
//
//  - **Point sources** — looping clips emitted from the `SFX_*` empties authored in the scene (e.g. the
//    fireplace, water, and the ring of street-ambience points inside the HomePod model). Each *type*
//    (matched by name prefix) shares one file and one tuning of loudness + reach, so the config exposes
//    a single volume / attenuation-radius pair per type rather than per point.
//  - **Rooftop ambience** — an optional single panoramic (non-positional) loop, spawned in code, that
//    surrounds the listener with a light sense of direction but no distance attenuation.
//
//  The controller scans the placed scene content for the emitters, so it is decoupled from the HomePod:
//  whichever scene carries the `SFX_*` empties gets the sound.
//

import Foundation
import RealityKit

@MainActor
final class AmbientSoundController {
    struct Configuration {
        struct Source {
            let namePrefix: String
            let file: String
            let volume: Float
            let attenuationRadius: Float
        }

        let sources: [Source]
        let rooftopFile: String?
        let rooftopVolume: Float
        let rooftopYawDegrees: Float
    }

    private let configuration: Configuration
    private let sceneRoot: Entity
    private let worldRoot: Entity
    private let locator: LevelResourceLocator

    /// Reference reach in metres that maps to RealityKit's default rolloff. A larger authored
    /// `attenuationRadius` yields a gentler rolloff (carries further); smaller is tighter and more local.
    private let referenceAttenuationRadius: Float = 5
    /// Below this a loop is effectively inaudible; we use it instead of -inf so the engine always has a
    /// finite target.
    private let silenceFloorDB: Audio.Decibel = -60

    private var pointControllers: [AudioPlaybackController] = []
    private var pointControllersByChannel: [String: [AudioPlaybackController]] = [:]
    private var channelVolumes: [String: Float]
    private var rooftopEntity: Entity?
    private var rooftopController: AudioPlaybackController?
    private var rooftopVolume: Float
    private var started = false

    /// `sceneRoot` is scanned for the `SFX_*` emitters; `worldRoot` hosts the spawned rooftop entity
    /// (so it sits in the locomotion frame and moves with teleport/recenter like everything else).
    init(configuration: Configuration, sceneRoot: Entity, worldRoot: Entity, locator: LevelResourceLocator) {
        self.configuration = configuration
        self.sceneRoot = sceneRoot
        self.worldRoot = worldRoot
        self.locator = locator
        self.channelVolumes = Dictionary(
            uniqueKeysWithValues: configuration.sources.map { ($0.namePrefix, Self.clampUnit($0.volume)) }
        )
        self.rooftopVolume = Self.clampUnit(configuration.rooftopVolume)
    }

    /// Load every loop and begin playback. Idempotent: a second call resumes already-prepared players.
    func start() {
        guard !started else {
            pointControllers.forEach { $0.play() }
            rooftopController?.play()
            return
        }
        started = true
        for source in configuration.sources { startPointSource(source) }
        startRooftop()
    }

    func stop() {
        started = false
        pointControllers.forEach { $0.stop() }
        pointControllers.removeAll()
        pointControllersByChannel.removeAll()
        rooftopController?.stop()
        rooftopController = nil
        rooftopEntity?.removeFromParent()
        rooftopEntity = nil
    }

    func setChannelVolume(_ channelID: String, _ volume: Float) {
        let clamped = Self.clampUnit(volume)
        channelVolumes[channelID] = clamped
        let target = decibels(forLinear: clamped)
        for controller in pointControllersByChannel[channelID] ?? [] {
            controller.fade(to: target, duration: 0.12)
        }
    }

    func setRooftopVolume(_ volume: Float) {
        rooftopVolume = Self.clampUnit(volume)
        rooftopController?.fade(to: decibels(forLinear: rooftopVolume), duration: 0.12)
    }

    // MARK: Point sources

    private func startPointSource(_ source: Configuration.Source) {
        let emitters = entities(withNamePrefix: source.namePrefix, in: sceneRoot)
        guard !emitters.isEmpty else { return }
        guard let url = try? locator.resolve(source.file) else {
            TimingDiagnostics.log("ambient: missing audio file \(source.file)")
            return
        }

        let attenuation = Audio.DistanceAttenuation.rolloff(factor: rolloffFactor(forRadius: source.attenuationRadius))
        for emitter in emitters {
            emitter.spatialAudio = SpatialAudioComponent(distanceAttenuation: attenuation)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var config = AudioFileResource.Configuration()
                config.shouldLoop = true
                let resource = try await AudioFileResource(contentsOf: url, configuration: config)
                guard self.started else { return }
                let gain = self.decibels(forLinear: self.channelVolumes[source.namePrefix] ?? source.volume)
                var controllers: [AudioPlaybackController] = []
                for emitter in emitters {
                    let controller = emitter.prepareAudio(resource)
                    controller.gain = gain
                    controller.play()
                    controllers.append(controller)
                    self.pointControllers.append(controller)
                }
                self.pointControllersByChannel[source.namePrefix] = controllers
            } catch {
                print("UP_AR ambient load failed for \(source.file): \(error.localizedDescription)")
            }
        }
    }

    // MARK: Rooftop

    private func startRooftop() {
        guard let file = configuration.rooftopFile, let url = try? locator.resolve(file) else { return }

        let entity = Entity()
        entity.name = "RooftopAmbient"
        // AmbientAudioComponent ignores distance; only orientation matters, rotating the recording's
        // directional field. Sit it at the origin and yaw it so the recording's "front" aligns.
        let yaw = configuration.rooftopYawDegrees * .pi / 180
        entity.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        entity.components.set(AmbientAudioComponent())
        worldRoot.addChild(entity)
        rooftopEntity = entity

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var config = AudioFileResource.Configuration()
                config.shouldLoop = true
                let resource = try await AudioFileResource(contentsOf: url, configuration: config)
                guard self.started, self.rooftopEntity === entity else { return }
                let controller = entity.prepareAudio(resource)
                controller.gain = self.decibels(forLinear: self.rooftopVolume)
                controller.play()
                self.rooftopController = controller
            } catch {
                print("UP_AR ambient rooftop load failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Helpers

    private func entities(withNamePrefix prefix: String, in root: Entity) -> [Entity] {
        var matches: [Entity] = []
        var stack: [Entity] = [root]
        while let entity = stack.popLast() {
            if entity.name.hasPrefix(prefix) { matches.append(entity) }
            stack.append(contentsOf: entity.children)
        }
        return matches
    }

    private func rolloffFactor(forRadius radius: Float) -> Double {
        let safeRadius = max(radius, 0.5)
        let factor = referenceAttenuationRadius / safeRadius
        return Double(min(max(factor, 0.1), 20))
    }

    private func decibels(forLinear linear: Float) -> Audio.Decibel {
        let clamped = Self.clampUnit(linear)
        guard clamped > 0.0001 else { return silenceFloorDB }
        return Audio.Decibel(20 * log10(Double(clamped)))
    }

    private static func clampUnit(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
