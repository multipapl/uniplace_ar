//
//  ReflectProcessor.swift
//  UP_AR (UniPlace)
//
//  Glossy non-glass surfaces (polished floors, metal, lacquer) that read the shared IBL. Keeps the
//  authored PhysicallyBasedMaterial but optionally re-points its textures at a second UV set and
//  unpacks an ORM (occlusion/roughness/metallic) atlas, then attaches a reflection receiver. Ported
//  from the AVP reflect path; the per-probe environment selection is deferred (shared IBL for now).
//

import Metal
import RealityKit

@MainActor
struct ReflectProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        // Probes were registered by the `probes` layer (ordered before this one); just attach receivers.
        applyReflectionReceivers(entity, context: context) { reflect(from: $0, params: params) }
    }

    private func reflect(from material: any RealityKit.Material, params: MaterialConfig.Params) -> any RealityKit.Material {
        guard var material = material as? PhysicallyBasedMaterial else { return material }
        if let uvIndex = params.reflectBaseColorUVIndex {
            material.baseColor = baseColorWithUVIndex(material.baseColor, uvIndex: uvIndex)
        }
        if let uvIndex = params.reflectMaterialUVIndex {
            applyPBRDataUVIndex(to: &material, uvIndex: uvIndex)
        }
        applyPackedMaterialIfNeeded(to: &material, packing: params.reflectMaterialPacking ?? "auto")
        return material
    }

    private func applyPBRDataUVIndex(to material: inout PhysicallyBasedMaterial, uvIndex: Int) {
        func repoint(_ texture: inout PhysicallyBasedMaterial.Texture?) {
            guard var t = texture else { return }
            t.uvIndex = uvIndex
            texture = t
        }
        repoint(&material.roughness.texture)
        repoint(&material.metallic.texture)
        repoint(&material.normal.texture)
        repoint(&material.ambientOcclusion.texture)
        repoint(&material.specular.texture)
        repoint(&material.clearcoat.texture)
        repoint(&material.clearcoatRoughness.texture)
        repoint(&material.emissiveColor.texture)
        if case let .transparent(opacity) = material.blending, var t = opacity.texture {
            t.uvIndex = uvIndex
            material.blending = .transparent(opacity: .init(scale: opacity.scale, texture: t))
        }
    }

    private func applyPackedMaterialIfNeeded(to material: inout PhysicallyBasedMaterial, packing: String) {
        guard packing != "none" else { return }
        if packing == "orm" {
            if let packed = material.ambientOcclusion.texture ?? material.roughness.texture ?? material.metallic.texture {
                applyORMMapping(from: packed, to: &material)
            }
            return
        }
        // "auto": complete an imported R/M pair that shares one texture by deriving the AO channel.
        guard material.ambientOcclusion.texture == nil,
              let roughness = material.roughness.texture,
              let metallic = material.metallic.texture,
              roughness.resource == metallic.resource,
              samplesSingleChannel(roughness, .green),
              samplesSingleChannel(metallic, .blue)
        else { return }
        var occlusion = roughness
        occlusion.swizzle = MTLTextureSwizzleChannels(red: .red, green: .red, blue: .red, alpha: .one)
        material.ambientOcclusion.texture = occlusion
    }

    private func applyORMMapping(from packed: PhysicallyBasedMaterial.Texture, to material: inout PhysicallyBasedMaterial) {
        var occlusion = packed
        occlusion.swizzle = MTLTextureSwizzleChannels(red: .red, green: .red, blue: .red, alpha: .one)
        material.ambientOcclusion.texture = occlusion

        var roughness = packed
        roughness.swizzle = MTLTextureSwizzleChannels(red: .green, green: .green, blue: .green, alpha: .one)
        material.roughness.texture = roughness

        var metallic = packed
        metallic.swizzle = MTLTextureSwizzleChannels(red: .blue, green: .blue, blue: .blue, alpha: .one)
        material.metallic.texture = metallic
    }

    private func samplesSingleChannel(_ texture: PhysicallyBasedMaterial.Texture, _ channel: MTLTextureSwizzle) -> Bool {
        texture.swizzle.red == channel && texture.swizzle.green == channel && texture.swizzle.blue == channel
    }
}
