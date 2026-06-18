//
//  EmissionProcessor.swift
//  UP_AR (UniPlace)
//
//  Self-illuminated surfaces (LED panels, light fixtures, glowing trim) split into their own layer.
//  ASSUMPTION (no AVP precedent — this layer is new to the AR build): in a baked-lighting pipeline an
//  emission layer is shown full-bright, which is exactly the unlit treatment. If these later need
//  additive blending / bloom, that change lives here alone. Confirm the intended look with the artist.
//

import RealityKit

@MainActor
struct EmissionProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        remapMaterials(entity, unlitMaterial(from:))
    }
}
