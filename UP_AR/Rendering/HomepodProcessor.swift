//
//  HomepodProcessor.swift
//  UP_AR (UniPlace)
//
//  The in-scene HomePod layer: the body renders like the baked scene (lights stripped, materials →
//  unlit), the screen mesh gets a looping opaque video material (same `LoopingVideoPlayback` as the
//  fire layer), and an empty `MusicEmitter` is placed at the body's visual-bounds centre to emit the
//  spatial background music. All driven by the `homepod*` / `music*` knobs.
//
//  Like the fire layer, this keeps the HomePod fully inside the rendering layer: the screen-video
//  player lifetime is anchored via `HomepodScreenComponent`, and the music tuning rides on the emitter
//  via `MusicEmitterComponent` — so the loader and app model know nothing about it. Whoever builds the
//  music controller (the AR session) just finds the named emitter and reads its component.
//

import RealityKit

/// Marks the HomePod layer root so the AR session can find it (for the tap-to-open-music gesture) and
/// walk down to the `MusicEmitter`.
struct HomepodComponent: Component {}

/// Holds the HomePod screen's video playback so its lifetime tracks the entity it is attached to.
struct HomepodScreenComponent: Component {
    let playback: LoopingVideoPlayback
}

/// Spatial-music playback tuning, carried from the manifest to the placed scene on the `MusicEmitter`
/// entity, so the music controller can be built purely from the loaded content.
struct MusicEmitterComponent: Component {
    let shuffle: Bool
    let defaultVolume: Float
    let gainBoostDB: Float
    let reverbPreset: String?
    let reverbLevelDB: Float
}

@MainActor
struct HomepodProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        entity.components.set(HomepodComponent())

        // Render the body like the base scene layer: strip authored lights, convert materials to unlit.
        removeSceneLighting(entity)
        remapMaterials(entity, unlitMaterial(from:))

        // The authored `SoundCollision` blocker mesh is a future raycast-occlusion aid, not visible
        // geometry — RealityKit can't occlude audio with it today. Hide it (kept for later wiring).
        entity.findEntity(named: "SoundCollision")?.isEnabled = false

        applyScreenVideo(to: entity, params: params, context: context)
        placeMusicEmitter(in: entity, params: params)
    }

    /// Override the screen mesh with the looping video material (opaque, writes depth so it occludes
    /// normally — unlike the alpha fire layer). A missing screen entity / video is logged, not fatal.
    private func applyScreenVideo(to entity: Entity, params: MaterialConfig.Params, context: MaterialContext) {
        guard let screenName = params.homepodScreenEntity, !screenName.isEmpty else { return }
        guard let screen = entity.findEntity(named: screenName) else {
            TimingDiagnostics.log("homepod layer: screen entity '\(screenName)' not found — no video")
            return
        }
        guard let videoName = params.homepodScreenVideo, !videoName.isEmpty,
              let url = context.resolve(videoName) else {
            TimingDiagnostics.log("homepod layer: screen video not configured/found — no video")
            return
        }

        let playback = LoopingVideoPlayback(url: url)
        let material = playback.makeMaterial(writesDepth: true)
        // The named screen entity is the Xform wrapper; the mesh sits on a like-named child, so apply
        // the material to every ModelComponent in the subtree (filling empty meshes too) — same as the
        // fire layer. Setting it only on the wrapper (which has no mesh) is why the screen stayed blank.
        applyVideoMaterial(material, to: screen)
        screen.components.set(HomepodScreenComponent(playback: playback))
        playback.start()
    }

    private func applyVideoMaterial(_ material: any RealityKit.Material, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components[ModelComponent.self] = model
        }
        for child in entity.children {
            applyVideoMaterial(material, to: child)
        }
    }

    /// Create the named `MusicEmitter` empty at the body's visual-bounds centre and tag it with the
    /// music tuning. Spatial audio emits from an entity's transform origin, not its mesh — and an
    /// exported body origin can sit at 0,0,0 (Blender "Apply Location"), so the bounds centre is the
    /// position that is correct regardless of the origin.
    private func placeMusicEmitter(in entity: Entity, params: MaterialConfig.Params) {
        let host = params.homepodBodyEntity.flatMap { entity.findEntity(named: $0) } ?? entity
        let emitter = Entity()
        emitter.name = "MusicEmitter"
        emitter.position = host.visualBounds(relativeTo: host).center
        emitter.components.set(MusicEmitterComponent(
            shuffle: params.musicShuffle ?? false,
            defaultVolume: params.musicDefaultVolume ?? 0.6,
            gainBoostDB: params.musicGainBoostDB ?? 10,
            reverbPreset: params.musicReverbPreset,
            reverbLevelDB: params.musicReverbLevelDB ?? -6
        ))
        host.addChild(emitter)
    }
}
