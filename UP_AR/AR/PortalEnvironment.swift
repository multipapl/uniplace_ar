//
//  PortalEnvironment.swift
//  UP_AR (UniPlace)
//
//  Configures an ARView as a hidden-feed "portal": ARKit world tracking drives the rendered camera
//  1:1, but the passthrough video is replaced by a flat virtual background. This is the core trick
//  that makes the iPad a virtual camera rather than a classic AR viewer.
//

import RealityKit
import ARKit
import UIKit

enum PortalEnvironment {
    /// Apply shared ARView setup. The background is switched separately because calibration shows
    /// the real camera feed, while the placed portal hides it.
    static func configure(_ arView: ARView) {
        arView.cameraMode = .ar
        arView.environment.sceneUnderstanding.options = []

        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableCameraGrain)
        arView.debugOptions = []
    }

    /// Passthrough mode: show the camera feed for calibration and drift debugging.
    static func showCalibrationFeed(_ arView: ARView) {
        arView.environment.background = .cameraFeed()
        arView.debugOptions = []
    }

    /// Portal mode: hide the passthrough feed behind a virtual background.
    static func showPortalBackground(_ arView: ARView) {
        arView.environment.background = .color(.init(white: 0.12, alpha: 1))
        arView.debugOptions = []
    }

    /// World-tracking config tuned for portal tracking: floor planes only, no texturing/lighting.
    static func makeConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        config.isLightEstimationEnabled = false
        config.worldAlignment = .gravity
        if let format = lightestSixtyFPSFormat() {
            config.videoFormat = format
        }
        return config
    }

    private static func lightestSixtyFPSFormat() -> ARConfiguration.VideoFormat? {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        let sixty = formats.filter { $0.framesPerSecond >= 60 }
        let pool = sixty.isEmpty ? formats : sixty
        return pool.min { lhs, rhs in
            (lhs.imageResolution.width * lhs.imageResolution.height) <
            (rhs.imageResolution.width * rhs.imageResolution.height)
        }
    }
}
