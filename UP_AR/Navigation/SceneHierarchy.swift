//
//  SceneHierarchy.swift
//  UP_AR (UniPlace)
//
//  The locomotion pivot:
//      originAnchor (calibrated floor pose, driven by a tracked ARAnchor)
//      └── calibrationRoot (manual height nudge only)
//          └── locomotionRoot (teleport/recenter offset only)
//              └── sceneContent (the level)
//
//  Physical walking is handled entirely by ARKit moving the camera through this tree.
//  Teleport and recenter mutate `locomotionRoot` only — the raw sensor pose is never touched.
//
//  Stability: when a session is available we bind `originAnchor` to a session-managed `ARAnchor`
//  rather than a fixed world transform. ARKit then keeps that anchor pinned to the physical floor as
//  it refines its world map (loop closure / relocalization), and RealityKit follows — so map
//  corrections no longer surface as visible horizontal/vertical jumps. Because ARKit owns the
//  `originAnchor` transform, the manual height correction lives on a separate `calibrationRoot`
//  node it won't overwrite.
//

import RealityKit
import ARKit

@MainActor
final class SceneHierarchy {
    static let floorAnchorName = "UPFloorAnchor"

    let originAnchor: AnchorEntity
    let calibrationRoot: Entity
    let locomotionRoot: Entity
    let sceneContent: Entity

    private let trackedAnchor: ARAnchor?
    private weak var session: ARSession?

    init(floorTransform: simd_float4x4, content: Entity, session: ARSession?) {
        if let session {
            let anchor = ARAnchor(name: SceneHierarchy.floorAnchorName, transform: floorTransform)
            session.add(anchor: anchor)
            originAnchor = AnchorEntity(anchor: anchor)
            trackedAnchor = anchor
        } else {
            // Simulator / no-AR path: nothing to track against, so pin to a fixed world transform.
            originAnchor = AnchorEntity(world: floorTransform)
            trackedAnchor = nil
        }
        self.session = session

        calibrationRoot = Entity()
        locomotionRoot = Entity()
        sceneContent = content

        locomotionRoot.addChild(sceneContent)
        calibrationRoot.addChild(locomotionRoot)
        originAnchor.addChild(calibrationRoot)
    }

    /// Drop the tracked ARAnchor from the session. Call before removing `originAnchor` from the scene
    /// so we don't leak anchors across scene switches.
    func detachFromSession() {
        guard let trackedAnchor, let session else { return }
        session.remove(anchor: trackedAnchor)
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

    /// Rotate the virtual scene around the user's current ground position.
    func rotateScene(degrees: Float, aroundWorldPoint pivot: SIMD3<Float>) {
        let radians = degrees * .pi / 180
        let rotation = simd_float4x4(simd_quatf(angle: radians, axis: [0, 1, 0]))
        let transform = translationMatrix(pivot) * rotation * translationMatrix(-pivot) *
            locomotionRoot.transformMatrix(relativeTo: nil)
        locomotionRoot.setTransformMatrix(transform, relativeTo: nil)
    }

    /// Nudge the whole scene vertically to correct a floor-height estimate. Applied on
    /// `calibrationRoot` (not `originAnchor`, which ARKit drives) so the correction survives.
    func nudgeHeight(_ delta: Float) {
        calibrationRoot.position.y += delta
    }

    private func translationMatrix(_ translation: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return matrix
    }
}
