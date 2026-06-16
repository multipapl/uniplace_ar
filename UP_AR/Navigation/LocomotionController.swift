//
//  LocomotionController.swift
//  UP_AR (UniPlace)
//
//  Pure, testable locomotion math. No RealityKit / ARKit dependencies so it can be unit-tested
//  directly (mirrors how the AVP app keeps LocomotionController stateless and tested).
//

import simd

enum LocomotionController {
    /// Horizontal world-space shift that brings `tappedWorld` under `userGround`.
    /// The vertical component is dropped so teleport never changes the viewer's height.
    nonisolated static func teleportShift(userGround: SIMD3<Float>,
                                          tappedWorld: SIMD3<Float>) -> SIMD3<Float> {
        var shift = userGround - tappedWorld
        shift.y = 0
        return shift
    }

    /// Reject non-finite or absurdly distant raycast results before acting on them.
    nonisolated static func isPlausibleTarget(_ p: SIMD3<Float>, maxRange: Float = 500) -> Bool {
        p.x.isFinite && p.y.isFinite && p.z.isFinite &&
        abs(p.x) <= maxRange && abs(p.y) <= maxRange && abs(p.z) <= maxRange
    }
}
