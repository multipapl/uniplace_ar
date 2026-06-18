//
//  MaterialSupport.swift
//  UP_AR (UniPlace)
//
//  Shared free functions used by several MaterialProcessors: stripping authored scene lighting,
//  the base PBR→Unlit conversion, tint maths, and the reflect/glass/water receiver walk. Keeping these
//  in one place stops every processor from re-implementing the same recursion. Ported from the AVP
//  MaterialPipeline monolith, split out so each processor stays small.
//

import Metal
import RealityKit
import UIKit

/// Remove authored lights so baked lighting in the textures is what shows (no realtime lighting cost).
@MainActor
func removeSceneLighting(_ entity: Entity) {
    entity.components.remove(DirectionalLightComponent.self)
    entity.components.remove(PointLightComponent.self)
    entity.components.remove(SpotLightComponent.self)
    entity.components.remove(ImageBasedLightComponent.self)
    entity.components.remove(ImageBasedLightReceiverComponent.self)
    for child in entity.children {
        removeSceneLighting(child)
    }
}

/// Base unlit conversion: keep the authored (baked) colour, drop realtime lighting, no back-face cull.
/// `applyPostProcessToneMap: false` keeps the baked colour exactly as authored.
@MainActor
func unlitMaterial(from material: any RealityKit.Material) -> any RealityKit.Material {
    switch material {
    case var material as UnlitMaterial:
        material.faceCulling = .none
        return material
    case let material as PhysicallyBasedMaterial:
        var unlit = UnlitMaterial(applyPostProcessToneMap: false)
        unlit.color = .init(tint: material.baseColor.tint, texture: material.baseColor.texture)
        unlit.faceCulling = .none
        unlit.blending = material.blending
        unlit.opacityThreshold = material.opacityThreshold
        return unlit
    case let material as SimpleMaterial:
        var unlit = UnlitMaterial(applyPostProcessToneMap: false)
        unlit.color = .init(tint: material.color.tint, texture: material.color.texture)
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

/// Recursively remap every ModelComponent's materials with `transform`.
@MainActor
func remapMaterials(_ entity: Entity, _ transform: (any RealityKit.Material) -> any RealityKit.Material) {
    if var model = entity.components[ModelComponent.self] {
        model.materials = model.materials.map(transform)
        entity.components[ModelComponent.self] = model
    }
    for child in entity.children {
        remapMaterials(child, transform)
    }
}

/// Walk a reflective layer: optionally swap each material, then attach a shared-IBL receiver to every
/// model. Reflect/glass pass a material transform; water passes `nil` to keep its authored material.
@MainActor
func applyReflectionReceivers(_ entity: Entity,
                             context: MaterialContext,
                             material: ((any RealityKit.Material) -> any RealityKit.Material)?) {
    if var model = entity.components[ModelComponent.self] {
        if let material {
            model.materials = model.materials.map(material)
            entity.components[ModelComponent.self] = model
        }
        context.reflection.applyReceiver(to: entity)
    }
    for child in entity.children {
        applyReflectionReceivers(child, context: context, material: material)
    }
}

// ─── tint maths ─────────────────────────────────────────────────────────────────
/// Configured tint × brightness as a multiplier, defaulting to neutral white when absent/malformed.
func tintMultiplier(_ values: [Float]?, brightness: Float?, default def: SIMD3<Float> = [1, 1, 1]) -> SIMD3<Float> {
    let base: SIMD3<Float>
    if let values, values.count == 3 {
        base = [values[0], values[1], values[2]]
    } else {
        base = def
    }
    return base * (brightness ?? 1)
}

/// Multiply a UIColor's RGB by a linear tint, preserving alpha.
func multiplyTint(_ color: UIColor, by tint: SIMD3<Float>) -> UIColor {
    var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return UIColor(red: r * CGFloat(tint.x), green: g * CGFloat(tint.y), blue: b * CGFloat(tint.z), alpha: a)
}

// ─── UV-index / packed-material helpers (reflect layer) ─────────────────────────
/// Re-point a base-colour texture at a different UV set (for layers authored with a 2nd UV channel).
func baseColorWithUVIndex(_ baseColor: PhysicallyBasedMaterial.BaseColor, uvIndex: Int) -> PhysicallyBasedMaterial.BaseColor {
    var baseColor = baseColor
    guard var texture = baseColor.texture else { return baseColor }
    texture.uvIndex = uvIndex
    baseColor.texture = texture
    return baseColor
}
