//
//  ARSessionController.swift
//  UP_AR (UniPlace)
//
//  Owns the ARSession lifecycle, handles taps (calibrate / teleport), builds the scene hierarchy,
//  and feeds debug read-outs back into AppModel. Implements the AppModel → AR action delegate.
//

import RealityKit
import ARKit
import QuartzCore
import UIKit

@MainActor
final class ARSessionController: NSObject, ARSessionDelegate, ARExperienceActions {
    private let appModel: AppModel
    private weak var arView: ARView?
    private var hierarchy: SceneHierarchy?
    private var calibrationPreviewAnchor: AnchorEntity?
    private var calibrationPreviewPlane: ModelEntity?
    private var latestCalibrationFloorTransform: simd_float4x4?
    private var calibrationStartedAt: CFTimeInterval = 0
    private var isPlacingScene = false
    private var isSessionRunning = false
    private var didLogFirstFrame = false
    private var didLogFirstFloorDetection = false
    private let levelProvider: LevelProvider = PlaceholderLevelProvider()

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastCalibrationReadoutTimestamp: CFTimeInterval = 0
    private let calibrationPreviewDelay: CFTimeInterval = 0.9

    // Throttle for the (background-queue) frame read-outs, so we only hop to the main actor ~10/s.
    private nonisolated(unsafe) var lastReadoutHop: TimeInterval = 0

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
        appModel.actions = self
    }

    func attach(to arView: ARView) {
        self.arView = arView
        PortalEnvironment.configure(arView)
        arView.session.delegate = self

        switch appModel.phase {
        case .start:
            PortalEnvironment.showPortalBackground(arView)
            startSession(resetTracking: true)
        case .calibrating:
            beginCalibration()
        case .placed:
            PortalEnvironment.showCalibrationFeed(arView)
            startSession(resetTracking: true)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tap)

        startDisplayLink()
    }

    private func startSession(resetTracking: Bool) {
        guard ARWorldTrackingConfiguration.isSupported else {
            appModel.lastMessage = "AR unavailable (simulator?) — tap to place the scene"
            appModel.finishShellWarmup()
            return
        }
        TimingDiagnostics.log("ARSession run begin")
        let options: ARSession.RunOptions = resetTracking
            ? [.resetTracking, .removeExistingAnchors]
            : []
        arView?.session.run(PortalEnvironment.makeConfiguration(),
                            options: options)
        isSessionRunning = true
        TimingDiagnostics.log("ARSession run returned")
    }

    func pause() {
        arView?.session.pause()
        isSessionRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)
        switch appModel.phase {
        case .calibrating: confirmCalibration()
        case .placed:      teleport(at: point)
        case .start:       break
        }
    }

    private func confirmCalibration() {
        guard let arView else { return }
        guard !isPlacingScene else { return }

        let floorTransform: simd_float4x4
        let eyeHeight: Float

        if let hit = currentCalibrationFloorTransform() {
            floorTransform = hit
            eyeHeight = arView.cameraTransform.translation.y - hit.columns.3.y
        } else if !ARWorldTrackingConfiguration.isSupported {
            // Simulator / no-AR fallback so the UI flow stays testable.
            floorTransform = matrix_identity_float4x4
            eyeHeight = 1.4
        } else {
            appModel.floorDetected = false
            removeCalibrationPreview()
            appModel.calibrationTitle = "Шукаю підлогу"
            appModel.lastMessage = "Підлогу ще не знайдено"
            return
        }

        isPlacingScene = true
        Task { await placeScene(floorTransform: floorTransform, eyeHeight: eyeHeight) }
    }

    private func placeScene(floorTransform: simd_float4x4, eyeHeight: Float) async {
        guard let arView else { return }
        defer { isPlacingScene = false }

        let content: Entity
        do {
            content = try await levelProvider.makeContent()
        } catch {
            appModel.lastMessage = "Failed to load scene: \(error.localizedDescription)"
            return
        }

        if let old = hierarchy {
            arView.scene.removeAnchor(old.originAnchor)
        }
        removeCalibrationPreview()
        PortalEnvironment.showCalibrationFeed(arView)
        let newHierarchy = SceneHierarchy(floorTransform: floorTransform, content: content)
        arView.scene.addAnchor(newHierarchy.originAnchor)
        hierarchy = newHierarchy

        appModel.eyeHeight = eyeHeight
        appModel.heightNudge = 0
        appModel.floorDetected = false
        latestCalibrationFloorTransform = nil
        appModel.phase = .placed
        appModel.lastMessage = "Walk, tap to teleport, or recenter"
        MemoryDiagnostics.log("scene placed")
    }

    private func teleport(at point: CGPoint) {
        guard let arView, let hierarchy else { return }
        guard let hit = arView.hitTest(point, query: .nearest, mask: .all).first else {
            appModel.lastMessage = "Tap a spot on the floor"
            return
        }

        let tappedWorld = hit.position
        guard LocomotionController.isPlausibleTarget(tappedWorld) else { return }

        let cam = arView.cameraTransform.translation
        let floorY = hierarchy.originAnchor.position(relativeTo: nil).y
        let userGround = SIMD3<Float>(cam.x, floorY, cam.z)
        let shift = LocomotionController.teleportShift(userGround: userGround, tappedWorld: tappedWorld)
        hierarchy.applyTeleportShift(shift)
        appModel.lastMessage = "Teleported"
    }

    // MARK: - ARExperienceActions

    func beginCalibration() {
        guard let arView else { return }
        removeCalibrationPreview()
        latestCalibrationFloorTransform = nil
        calibrationStartedAt = CACurrentMediaTime()
        isPlacingScene = false
        didLogFirstFrame = false
        didLogFirstFloorDetection = false
        lastCalibrationReadoutTimestamp = 0
        PortalEnvironment.showCalibrationFeed(arView)
        appModel.floorDetected = false
        appModel.calibrationTitle = "Підготовка"
        appModel.lastMessage = "Стань у стартову позицію"
        if !isSessionRunning {
            startSession(resetTracking: true)
        }
    }

    func recenter() {
        hierarchy?.recenter()
    }

    func recalibrate() {
        if let arView, let old = hierarchy {
            arView.scene.removeAnchor(old.originAnchor)
        }
        hierarchy = nil
        appModel.phase = .calibrating
        beginCalibration()
    }

    func nudgeHeight(_ delta: Float) {
        hierarchy?.nudgeHeight(delta)
        appModel.heightNudge += delta
        appModel.eyeHeight -= delta   // raising the scene lowers the apparent eye height
    }

    // MARK: - ARSessionDelegate (debug read-outs)

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
        Task { @MainActor [weak self] in
            guard let self, !didLogFirstFrame else { return }
            didLogFirstFrame = true
            TimingDiagnostics.log("first AR frame")
            appModel.finishShellWarmup()
        }

        guard timestamp - lastReadoutHop > 0.1 else { return }
        lastReadoutHop = timestamp

        let tracking = Self.label(for: frame.camera.trackingState)
        let c = frame.camera.transform.columns.3
        let pose = String(format: "x %.2f  y %.2f  z %.2f", c.x, c.y, c.z)

        Task { @MainActor [weak self] in
            self?.consumeReadout(tracking: tracking, pose: pose)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.appModel.lastMessage = "AR error: \(message)"
        }
    }

    private func consumeReadout(tracking: String, pose: String) {
        guard appModel.showDebugOverlay else { return }
        appModel.trackingStateLabel = tracking
        appModel.poseLabel = pose
    }

    nonisolated private static func label(for state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal: return "Normal"
        case .notAvailable: return "Not available"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Limited · initializing"
            case .excessiveMotion: return "Limited · excessive motion"
            case .insufficientFeatures: return "Limited · few features"
            case .relocalizing: return "Limited · relocalizing"
            @unknown default: return "Limited"
            }
        @unknown default: return "—"
        }
    }

    // MARK: - FPS (true render cadence)

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastFrameTimestamp = link.timestamp }
        updateCalibrationReadout()
        guard appModel.showDebugOverlay, lastFrameTimestamp != 0 else { return }
        let dt = link.timestamp - lastFrameTimestamp
        if dt > 0 { appModel.fps = 1.0 / dt }
    }

    private func updateCalibrationReadout() {
        guard appModel.phase == .calibrating else { return }
        guard ARWorldTrackingConfiguration.isSupported else { return }
        guard arView != nil else { return }
        let now = CACurrentMediaTime()
        guard now - lastCalibrationReadoutTimestamp >= 0.2 else { return }
        lastCalibrationReadoutTimestamp = now

        let floorTransform = currentCalibrationFloorTransform()
        guard now - calibrationStartedAt >= calibrationPreviewDelay else {
            removeCalibrationPreview()
            if appModel.floorDetected {
                appModel.floorDetected = false
            }
            appModel.calibrationTitle = "Підготовка"
            appModel.lastMessage = "Стань у стартову позицію"
            return
        }

        let detected = floorTransform != nil
        if let floorTransform {
            if !didLogFirstFloorDetection {
                didLogFirstFloorDetection = true
                TimingDiagnostics.log("first floor detection")
            }
            updateCalibrationPreview(floorTransform)
        } else {
            removeCalibrationPreview()
        }
        guard detected != appModel.floorDetected else { return }

        appModel.floorDetected = detected
        appModel.calibrationTitle = detected
            ? "Підлогу знайдено"
            : "Шукаю підлогу"
        appModel.lastMessage = detected
            ? "Тапни, щоб підтвердити старт"
            : "Наведи центр на підлогу"
    }

    private func reticlePoint(in arView: ARView) -> CGPoint {
        CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    }

    private func currentCalibrationFloorTransform() -> simd_float4x4? {
        if let raycastTransform = reticleFloorRaycast() {
            latestCalibrationFloorTransform = raycastTransform
            return raycastTransform
        }
        if let sampledTransform = sampledFloorRaycast() {
            let reticleTransform = transformAtReticle(floorY: sampledTransform.columns.3.y) ?? sampledTransform
            latestCalibrationFloorTransform = reticleTransform
            return reticleTransform
        }
        if let anchorTransform = largestHorizontalPlaneTransform() {
            let reticleTransform = transformAtReticle(floorY: anchorTransform.columns.3.y) ?? anchorTransform
            latestCalibrationFloorTransform = reticleTransform
            return reticleTransform
        }
        return latestCalibrationFloorTransform
    }

    private func reticleFloorRaycast() -> simd_float4x4? {
        guard let arView else { return nil }
        let center = reticlePoint(in: arView)
        if let hit = floorRaycast(at: center, allowing: .existingPlaneGeometry) {
            return hit
        }
        return floorRaycast(at: center, allowing: .estimatedPlane)
    }

    private func sampledFloorRaycast() -> simd_float4x4? {
        guard let arView else { return nil }
        for point in calibrationSearchPoints(in: arView) {
            if let hit = floorRaycast(at: point, allowing: .existingPlaneGeometry) {
                return hit
            }
            if let hit = floorRaycast(at: point, allowing: .estimatedPlane) {
                return hit
            }
        }
        return nil
    }

    private func calibrationSearchPoints(in arView: ARView) -> [CGPoint] {
        let center = reticlePoint(in: arView)
        let bounds = arView.bounds
        guard bounds.width > 1, bounds.height > 1 else { return [center] }

        let offset = min(bounds.width, bounds.height) * 0.16
        return [
            center,
            CGPoint(x: center.x, y: center.y + offset),
            CGPoint(x: center.x - offset, y: center.y),
            CGPoint(x: center.x + offset, y: center.y),
            CGPoint(x: center.x, y: center.y - offset)
        ]
    }

    private func transformAtReticle(floorY: Float) -> simd_float4x4? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let cameraTransform = frame.camera.transform
        let origin = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let forward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        guard abs(forward.y) > 0.001 else { return nil }

        let distance = (floorY - origin.y) / forward.y
        guard distance > 0 else { return nil }

        let position = origin + forward * distance
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(position.x, floorY, position.z, 1)
        return transform
    }

    private func floorRaycast(at point: CGPoint,
                              allowing target: ARRaycastQuery.Target) -> simd_float4x4? {
        guard let arView else { return nil }
        guard let query = arView.makeRaycastQuery(from: point,
                                                  allowing: target,
                                                  alignment: .horizontal) else { return nil }
        return arView.session.raycast(query).first?.worldTransform
    }

    private func largestHorizontalPlaneTransform() -> simd_float4x4? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let plane = frame.anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { $0.alignment == .horizontal }
            .max { lhs, rhs in
                (lhs.planeExtent.width * lhs.planeExtent.height) <
                    (rhs.planeExtent.width * rhs.planeExtent.height)
            }

        guard let plane else { return nil }
        var transform = plane.transform
        let center = SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1)
        transform.columns.3 = plane.transform * center
        return transform
    }

    private func updateCalibrationPreview(_ floorTransform: simd_float4x4) {
        guard let arView else { return }

        let anchor: AnchorEntity
        if let calibrationPreviewAnchor {
            anchor = calibrationPreviewAnchor
            anchor.setTransformMatrix(floorTransform, relativeTo: nil)
        } else {
            anchor = AnchorEntity(world: floorTransform)
            calibrationPreviewAnchor = anchor
            arView.scene.addAnchor(anchor)
        }

        if calibrationPreviewPlane == nil {
            var material = UnlitMaterial(color: UIColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 0.14))
            material.blending = .transparent(opacity: 0.14)

            let plane = ModelEntity(mesh: .generatePlane(width: 1.45, depth: 1.45),
                                    materials: [material])
            plane.name = "CalibrationFloorPreview"
            plane.position.y = 0.002
            calibrationPreviewPlane = plane
            anchor.addChild(plane)
            addCalibrationPreviewDots(to: anchor)
        }
    }

    private func addCalibrationPreviewDots(to anchor: AnchorEntity) {
        var dotMaterial = UnlitMaterial(color: UIColor(red: 0.65, green: 1.0, blue: 1.0, alpha: 0.58))
        dotMaterial.blending = .transparent(opacity: 0.58)

        let dotSize: Float = 0.026
        let spacing: Float = 0.18
        let count = 7
        let origin = -Float(count - 1) * spacing / 2

        for row in 0..<count {
            for column in 0..<count {
                let dot = ModelEntity(mesh: .generatePlane(width: dotSize, depth: dotSize),
                                      materials: [dotMaterial])
                dot.name = "CalibrationFloorPreviewDot"
                dot.position = [
                    origin + Float(column) * spacing,
                    0.006,
                    origin + Float(row) * spacing
                ]
                anchor.addChild(dot)
            }
        }
    }

    private func removeCalibrationPreview() {
        guard let anchor = calibrationPreviewAnchor else { return }
        arView?.scene.removeAnchor(anchor)
        calibrationPreviewAnchor = nil
        calibrationPreviewPlane = nil
    }
}
