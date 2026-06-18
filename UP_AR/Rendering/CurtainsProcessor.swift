//
//  CurtainsProcessor.swift
//  UP_AR (UniPlace)
//
//  Sheer curtains: unlit, tinted/brightened, semi-transparent, and rendered in a depth pre-pass
//  (ModelSortGroupComponent) so the translucent fabric sorts correctly against the room behind it.
//  Ported from the AVP curtains path. Empty-material meshes get a plain tinted fallback.
//

import RealityKit
import UIKit

@MainActor
struct CurtainsProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        apply(entity, params: params)
    }

    private func apply(_ entity: Entity, params: MaterialConfig.Params) {
        if var model = entity.components[ModelComponent.self] {
            entity.components.set(ModelSortGroupComponent(group: ModelSortGroup(depthPass: .prePass), order: 0))
            if model.materials.isEmpty {
                model.materials = [curtain(from: nil, params: params)]
            } else {
                model.materials = model.materials.map { curtain(from: $0, params: params) }
            }
            entity.components[ModelComponent.self] = model
        }
        for child in entity.children {
            apply(child, params: params)
        }
    }

    private func curtain(from source: (any RealityKit.Material)?, params: MaterialConfig.Params) -> any RealityKit.Material {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        let sourceColor: UnlitMaterial.BaseColor
        switch source {
        case let source as PhysicallyBasedMaterial:
            sourceColor = .init(tint: source.baseColor.tint, texture: source.baseColor.texture)
        case let source as UnlitMaterial:
            sourceColor = source.color
        case let source as SimpleMaterial:
            sourceColor = .init(tint: source.color.tint, texture: source.color.texture)
        default:
            sourceColor = .init(tint: .white)
        }

        let tint = tintMultiplier(params.curtainTint, brightness: params.curtainBrightness ?? 1.4)
        material.color = .init(tint: multiplyTint(sourceColor.tint, by: tint), texture: sourceColor.texture)
        material.faceCulling = .none
        material.blending = .transparent(opacity: .init(scale: params.curtainOpacity ?? 0.82))
        material.readsDepth = true
        material.writesDepth = true
        return material
    }
}
