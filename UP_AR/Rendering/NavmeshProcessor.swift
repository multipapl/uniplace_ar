//
//  NavmeshProcessor.swift
//  UP_AR (UniPlace)
//
//  The navigation-mesh layer (AVP's "Walkable", renamed): invisible geometry that defines where
//  teleport is allowed. Generates precise static-mesh collision so teleport raycasts land only on
//  valid floor, then hides the meshes. `debugVisible` (MaterialConfig) draws it as a translucent
//  overlay for tuning. Ported from the AVP WalkableSurfaceSystem.
//

import RealityKit
import UIKit

@MainActor
struct NavmeshProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        await apply(entity, debugVisible: params.debugVisible ?? false)
    }

    private func apply(_ entity: Entity, debugVisible: Bool) async {
        if entity.components[ModelComponent.self] != nil {
            await addCollision(to: entity)
            if debugVisible {
                showDebug(entity)
            } else {
                entity.components.remove(ModelComponent.self)
            }
        }
        for child in entity.children {
            await apply(child, debugVisible: debugVisible)
        }
    }

    private func addCollision(to entity: Entity) async {
        guard let model = entity.components[ModelComponent.self] else { return }
        if let shape = try? await ShapeResource.generateStaticMesh(from: model.mesh) {
            entity.components.set(CollisionComponent(shapes: [shape], isStatic: true))
        } else {
            entity.generateCollisionShapes(recursive: false, static: true)
        }
    }

    private func showDebug(_ entity: Entity) {
        guard var model = entity.components[ModelComponent.self] else { return }
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor.cyan.withAlphaComponent(0.55))
        material.faceCulling = .none
        material.blending = .transparent(opacity: 0.55)
        model.materials = [material]
        entity.components[ModelComponent.self] = model
    }
}
