//
//  FireProcessor.swift
//  UP_AR (UniPlace)
//
//  The animated fire: a looping alpha video (RealityKit `VideoMaterial`) applied to the fire mesh.
//  The video clip is named by the `fireVideo` knob and resolved from the bundle. Lighting is stripped
//  (the clip is its own light), then the video material replaces every material on the subtree.
//
//  Player lifetime is anchored to the entity via `FireVideoComponent`: when the scene tears down the
//  entity tree is released, the component drops, `LoopingVideoPlayback` deinits and pauses the decoder.
//  This keeps the fire fully inside the rendering layer — the loader and app model know nothing about it.
//

import RealityKit

/// Holds the fire's video playback so its lifetime tracks the entity it is attached to.
struct FireVideoComponent: Component {
    let playback: LoopingVideoPlayback
}

@MainActor
struct FireProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)

        guard let videoName = params.fireVideo, !videoName.isEmpty else {
            TimingDiagnostics.log("fire layer: no 'fireVideo' configured — left as-is")
            return
        }
        guard let url = context.resolve(videoName) else {
            TimingDiagnostics.log("fire layer: video '\(videoName)' not found in bundle — left as-is")
            return
        }

        let playback = LoopingVideoPlayback(url: url)
        let material = playback.makeMaterial()
        applyMaterial(material, to: entity)
        entity.components.set(FireVideoComponent(playback: playback))
        playback.start()
    }

    /// Replace every material in the subtree with the one video material (filling empty meshes too).
    private func applyMaterial(_ material: any RealityKit.Material, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components[ModelComponent.self] = model
        }
        for child in entity.children {
            applyMaterial(material, to: child)
        }
    }
}
