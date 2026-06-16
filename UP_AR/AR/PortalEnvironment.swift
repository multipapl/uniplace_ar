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
    /// Apply the portal look to an ARView: AR camera mode (so the device pose drives the rendered
    /// camera), passthrough feed hidden behind a neutral grey, no real-world compositing.
    static func configure(_ arView: ARView) {
        arView.cameraMode = .ar
        arView.environment.background = .color(.init(white: 0.5, alpha: 1))
        arView.environment.sceneUnderstanding.options = []

        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableCameraGrain)
        arView.debugOptions = []
    }

    /// World-tracking config tuned for a hidden-feed portal: floor planes only, no texturing/lighting,
    /// lightest 60-fps video format (the feed is hidden, so resolution is wasted bandwidth/heat).
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
