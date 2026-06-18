//
//  GlassProcessor.swift
//  UP_AR (UniPlace)
//
//  Windows / glazing: a generated transparent PhysicallyBasedMaterial (low roughness, clearcoat) that
//  reflects the shared image-based-light environment. Prepares the shared IBL on first use, then swaps
//  each glass material and attaches a reflection receiver. Ported from the AVP glass path.
//

import RealityKit

@MainActor
struct GlassProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        // Probes were registered by the `probes` layer (ordered before this one); just attach receivers.
        applyReflectionReceivers(entity, context: context) { glass(from: $0, params: params) }
    }

    private func glass(from material: any RealityKit.Material, params: MaterialConfig.Params) -> any RealityKit.Material {
        var glass = material as? PhysicallyBasedMaterial ?? PhysicallyBasedMaterial()
        glass.metallic = .init(scale: 0)
        glass.roughness = .init(scale: params.glassRoughness ?? 0.03)
        glass.specular = .init(scale: params.glassSpecular ?? 1.0)
        glass.clearcoat = .init(scale: params.glassClearcoat ?? 1.0)
        glass.clearcoatRoughness = .init(scale: params.glassClearcoatRoughness ?? 0.02)
        glass.blending = .transparent(opacity: .init(scale: params.glassOpacity ?? 0.18))
        glass.faceCulling = .none
        glass.writesDepth = false
        return glass
    }
}
