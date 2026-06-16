//
//  SceneHierarchy.swift
//  UP_AR (UniPlace)
//
//  The locomotion pivot: originAnchor (calibrated floor pose) → locomotionRoot (teleport/recenter
//  offset only) → sceneContent (the level; a placeholder cube in Phase 1).
//
//  Physical walking is handled entirely by ARKit moving the camera through this static tree.
//  Teleport and recenter mutate `locomotionRoot` only — the raw sensor pose is never touched.
//

import RealityKit

@MainActor
final class SceneHierarchy {
    let originAnchor: AnchorEntity
    let locomotionRoot: Entity
    let sceneContent: Entity

    init(floorTransform: simd_float4x4, content: Entity) {
        originAnchor = AnchorEntity(world: floorTransform)
        locomotionRoot = Entity()
        sceneContent = content

        locomotionRoot.addChild(sceneContent)
        originAnchor.addChild(locomotionRoot)
    }

    /// Clear teleport drift, returning to the calibrated spawn.
    func recenter() {
        locomotionRoot.transform = .identity
    }

    /// Shift the scene horizontally so a tapped world point comes under the user. Offset only.
    func applyTeleportShift(_ worldShift: SIMD3<Float>) {
        let current = locomotionRoot.position(relativeTo: nil)
        locomotionRoot.setPosition(current + worldShift, relativeTo: nil)
    }

    /// Nudge the whole scene vertically to correct a floor-height estimate.
    func nudgeHeight(_ delta: Float) {
        originAnchor.position.y += delta
    }
}
