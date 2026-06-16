//
//  UnlitProcessor.swift
//  UP_AR (UniPlace)
//
//  The base visible layer: strip authored scene lights and convert every material to UnlitMaterial,
//  so baked lighting carried by the textures shows as-authored with no realtime lighting cost. Ported
//  from the AVP MaterialPipeline base-scene path (the minimal unlit subset only).
//

import RealityKit
import UIKit

@MainActor
struct UnlitProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        convertToUnlit(entity)
    }

    private func removeSceneLighting(_ entity: Entity) {
        entity.components.remove(DirectionalLightComponent.self)
        entity.components.remove(PointLightComponent.self)
        entity.components.remove(SpotLightComponent.self)
        entity.components.remove(ImageBasedLightComponent.self)
        entity.components.remove(ImageBasedLightReceiverComponent.self)
        for child in entity.children {
            removeSceneLighting(child)
        }
    }

    private func convertToUnlit(_ entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map(unlit(from:))
            entity.components[ModelComponent.self] = model
        }
        for child in entity.children {
            convertToUnlit(child)
        }
    }

    /// `applyPostProcessToneMap: false` keeps the baked colour exactly as authored.
    private func unlit(from material: any RealityKit.Material) -> any RealityKit.Material {
        switch material {
        case var material as UnlitMaterial:
            material.faceCulling = .none
            return material
        case let material as PhysicallyBasedMaterial:
            var unlit = UnlitMaterial(applyPostProcessToneMap: false)
            unlit.color = material.baseColor
            unlit.faceCulling = .none
            unlit.blending = material.blending
            unlit.opacityThreshold = material.opacityThreshold
            return unlit
        case let material as SimpleMaterial:
            var unlit = UnlitMaterial(applyPostProcessToneMap: false)
            unlit.color = material.color
            unlit.faceCulling = .none
            return unlit
        case var material as ShaderGraphMaterial:
            material.faceCulling = .none
            return material
        default:
            var unlit = UnlitMaterial(applyPostProcessToneMap: false)
            unlit.color = .init(tint: .white)
            unlit.faceCulling = .none
            return unlit
        }
    }
}
