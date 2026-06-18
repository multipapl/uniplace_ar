//
//  TranslucentProcessor.swift
//  UP_AR (UniPlace)
//
//  Alpha-tested cutout surfaces (foliage, decals). Converts PBR to unlit and drives the hard alpha clip
//  from the authored opacity mask. Two details that this content lineage needs:
//   • the mask and the base colour are on DIFFERENT UV sets (mask on UV0, base colour on UV1), set via
//     `translucentAlphaUVIndex` / `translucentBaseColorUVIndex`;
//   • the mask is a greyscale jpg with data in RED (no alpha), so the opacity texture is swizzled to
//     sample red.
//  A base-colour-alpha fallback covers layers whose opacity was folded into the base texture's alpha.
//

import Metal
import RealityKit

@MainActor
struct TranslucentProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        let alphaCutoff = params.translucentAlphaCutoff ?? 0.5
        remapMaterials(entity) { translucent(from: $0, params: params, alphaCutoff: alphaCutoff) }
    }

    private func translucent(from material: any RealityKit.Material,
                             params: MaterialConfig.Params,
                             alphaCutoff: Float) -> any RealityKit.Material {
        switch material {
        case let material as PhysicallyBasedMaterial:
            var unlit = UnlitMaterial(applyPostProcessToneMap: false)
            var baseColor = material.baseColor
            if let uvIndex = params.translucentBaseColorUVIndex {
                baseColor = baseColorWithUVIndex(baseColor, uvIndex: uvIndex)
            }
            unlit.color = .init(tint: baseColor.tint, texture: baseColor.texture)
            unlit.faceCulling = .none

            if case let .transparent(opacity) = material.blending, var tex = opacity.texture {
                // Greyscale mask: data is in RED, so force opacity to sample red (the default reads the
                // empty alpha = 1 → nothing clips).
                tex.swizzle = MTLTextureSwizzleChannels(red: .red, green: .red, blue: .red, alpha: .red)
                if let uvIndex = params.translucentAlphaUVIndex { tex.uvIndex = uvIndex }
                unlit.blending = .transparent(opacity: .init(scale: 1, texture: tex))
            } else if let alphaTex = alphaFromBaseColor(baseColor.texture) {
                unlit.blending = .transparent(opacity: .init(scale: 1, texture: alphaTex))
            } else {
                unlit.blending = material.blending
            }
            unlit.opacityThreshold = max(material.opacityThreshold ?? 0, alphaCutoff)
            unlit.writesDepth = true
            return unlit
        case var material as UnlitMaterial:
            material.faceCulling = .none
            if (material.opacityThreshold ?? 0) <= 0 { material.opacityThreshold = alphaCutoff }
            material.writesDepth = true
            return material
        case var material as ShaderGraphMaterial:
            material.faceCulling = .none
            return material
        default:
            var unlit = unlitMaterial(from: material) as? UnlitMaterial ?? UnlitMaterial(applyPostProcessToneMap: false)
            unlit.faceCulling = .none
            if (unlit.opacityThreshold ?? 0) <= 0 { unlit.opacityThreshold = alphaCutoff }
            unlit.writesDepth = true
            return unlit
        }
    }

    /// Treat the base-colour texture's alpha channel as opacity (broadcast alpha across rgb).
    private func alphaFromBaseColor(_ texture: PhysicallyBasedMaterial.Texture?) -> PhysicallyBasedMaterial.Texture? {
        guard var texture else { return nil }
        texture.swizzle = MTLTextureSwizzleChannels(red: .alpha, green: .alpha, blue: .alpha, alpha: .one)
        return texture
    }
}
