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

        // The portal hides the passthrough feed, so camera sharpness buys us nothing — but autofocus
        // hunting shifts the camera intrinsics and surfaces as a "breathing"/refocusing jitter in the
        // tracked pose. Lock focus to keep the rendered scene steady.
        config.isAutoFocusEnabled = false

        // LiDAR (Pro devices): the depth mesh makes floor detection near-instant and more accurate,
        // and steadies tracking. We don't use the mesh for occlusion (the portal hides passthrough),
        // only as a tracking/plane-fitting aid.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        if let format = preferredVideoFormat() {
            config.videoFormat = format
        }
        return config
    }

    /// Pick the 60 FPS camera format. Capable devices (LiDAR present) can afford the highest-resolution
    /// 60 FPS feed — more visual features → steadier tracking. Weaker devices keep the lightest 60 FPS
    /// format to protect the framerate of the rendered scene.
    private static func preferredVideoFormat() -> ARConfiguration.VideoFormat? {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        let sixty = formats.filter { $0.framesPerSecond >= 60 }
        let pool = sixty.isEmpty ? formats : sixty
        guard !pool.isEmpty else { return nil }

        let capable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        return capable
            ? pool.max { pixelCount($0) < pixelCount($1) }
            : pool.min { pixelCount($0) < pixelCount($1) }
    }

    private static func pixelCount(_ format: ARConfiguration.VideoFormat) -> Double {
        format.imageResolution.width * format.imageResolution.height
    }
}
