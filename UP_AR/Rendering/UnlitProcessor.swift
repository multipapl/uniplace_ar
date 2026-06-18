//
//  UnlitProcessor.swift
//  UP_AR (UniPlace)
//
//  The base visible layer: strip authored scene lights and convert every material to UnlitMaterial,
//  so baked lighting carried by the textures shows as-authored with no realtime lighting cost. Ported
//  from the AVP MaterialPipeline base-scene path (the minimal unlit subset only).
//

import RealityKit

@MainActor
struct UnlitProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        remapMaterials(entity, unlitMaterial(from:))
    }
}
