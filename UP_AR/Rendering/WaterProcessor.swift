//
//  WaterProcessor.swift
//  UP_AR (UniPlace)
//
//  Water surfaces keep their authored Reality Composer Pro ShaderGraph material (animated ripples,
//  refraction) and only gain a reflection receiver pointing at the shared IBL — unlike glass/reflect
//  which swap the material for a generated one. Ported from the AVP water path (`material: nil`).
//

import RealityKit

@MainActor
struct WaterProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        // Probes were registered by the `probes` layer (ordered before this one); just attach receivers.
        applyReflectionReceivers(entity, context: context, material: nil)
    }
}
