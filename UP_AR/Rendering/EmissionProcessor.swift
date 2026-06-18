//
//  EmissionProcessor.swift
//  UP_AR (UniPlace)
//
//  Self-illuminated surfaces (LED panels, light fixtures, glowing trim) split into their own layer.
//  In a baked-lighting pipeline an emission layer is shown unlit but pushed brighter than 1.0 so it
//  reads as a light source rather than a flat texture — the baked colour is multiplied by a tint ×
//  brightness (default ×2). If these later need additive blending / bloom, that change lives here alone.
//

import RealityKit

@MainActor
struct EmissionProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        let tint = tintMultiplier(params.emissionTint, brightness: params.emissionBrightness ?? 2)
        remapMaterials(entity) { source in
            let base = unlitMaterial(from: source)
            guard var unlit = base as? UnlitMaterial else { return base }
            unlit.color = .init(tint: multiplyTint(unlit.color.tint, by: tint), texture: unlit.color.texture)
            return unlit
        }
    }
}
