//
//  LocomotionController.swift
//  UP_AR (UniPlace)
//
//  Pure, testable locomotion math. No RealityKit / ARKit dependencies so it can be unit-tested
//  directly (mirrors how the AVP app keeps LocomotionController stateless and tested).
//

import Foundation
import simd

enum LocomotionController {
    /// Yaw (radians, about +Y) for the scene origin so the viewer spawns facing the authored
    /// direction: the scene's spawn-forward (local −Z turned by `spawnYawRadians`) is aligned to the
    /// camera's current horizontal heading. `cameraForward` is the camera's −Z axis in world space.
    /// Because the origin carries this rotation and the spawn empty sits at the origin, the scene
    /// rotates about the user's feet — so wherever the iPad physically points at calibration, the
    /// viewer ends up looking down the authored spawn direction.
    nonisolated static func spawnOriginYaw(cameraForward: SIMD3<Float>,
                                           spawnYawRadians: Float) -> Float {
        let cameraHeading = atan2(-cameraForward.x, -cameraForward.z)
        return cameraHeading - spawnYawRadians
    }

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
