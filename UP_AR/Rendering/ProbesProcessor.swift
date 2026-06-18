//
//  ProbesProcessor.swift
//  UP_AR (UniPlace)
//
//  Reflection probes: invisible anchor planes marking where a 360° reflection was captured. This
//  processor reads each plane's position and registers a per-probe IBL into the shared
//  ReflectionEnvironment (env maps come from Content/ProbesTextures via probes.json), then hides the
//  geometry. Must run BEFORE the reflective layers (reflect/glass/water) so their receivers find probes.
//

import Foundation
import RealityKit

@MainActor
struct ProbesProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        context.probesScene = entity
        await context.reflection.registerProbes(
            from: entity,
            mapping: loadMapping(resolve: context.resolve),
            worldRoot: context.worldRoot,
            resolve: context.resolve,
            intensityExponent: params.reflectionIntensityExponent ?? 1.4)
        hideGeometry(entity)
    }

    /// plane name → env image file, written next to the extracted maps by the optimizer.
    private func loadMapping(resolve: (String) -> URL?) -> [String: String] {
        guard let url = resolve("probes.json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    private func hideGeometry(_ entity: Entity) {
        entity.components.remove(ModelComponent.self)
        for child in entity.children {
            hideGeometry(child)
        }
    }
}
