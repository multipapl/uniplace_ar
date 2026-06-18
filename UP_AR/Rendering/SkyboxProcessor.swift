//
//  SkyboxProcessor.swift
//  UP_AR (UniPlace)
//
//  The shared sky dome: unlit, tinted/brightened by config, and (by default) writing depth so it sits
//  behind everything as the background. `skyOpacity < 1` makes it a translucent overlay instead.
//  Ported from the AVP MaterialPipeline sky path. This is the one layer shared by both scenes.
//

import RealityKit
import UIKit

@MainActor
struct SkyboxProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)
        let tint = tintMultiplier(params.skyTint, brightness: params.skyBrightness)
        let opacity = params.skyOpacity
        remapMaterials(entity) { material in
            var unlit = unlitMaterial(from: material) as? UnlitMaterial ?? UnlitMaterial(applyPostProcessToneMap: false)
            unlit.color = .init(tint: multiplyTint(unlit.color.tint, by: tint), texture: unlit.color.texture)
            unlit.faceCulling = .none
            if let opacity, opacity < 1 {
                unlit.blending = .transparent(opacity: .init(scale: opacity))
            } else {
                unlit.writesDepth = true
            }
            return unlit
        }
    }
}
