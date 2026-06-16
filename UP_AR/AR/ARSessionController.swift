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

@MainActor
final class ARSessionController: NSObject, ARSessionDelegate, ARExperienceActions {
    private let appModel: AppModel
    private weak var arView: ARView?
    private var hierarchy: SceneHierarchy?
    private let levelProvider: LevelProvider = PlaceholderLevelProvider()

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0

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

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tap)

        startSession()
        startDisplayLink()
    }

    private func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            appModel.lastMessage = "AR unavailable (simulator?) — tap to place the scene"
            return
        }
        arView?.session.run(PortalEnvironment.makeConfiguration(),
                            options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        arView?.session.pause()
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)
        switch appModel.phase {
        case .calibrating: calibrate(at: point)
        case .placed:      teleport(at: point)
        case .start:       break
        }
    }

    private func calibrate(at point: CGPoint) {
        guard let arView else { return }

        let floorTransform: simd_float4x4
        let eyeHeight: Float

        if let hit = floorRaycast(at: point) {
            floorTransform = hit
            eyeHeight = arView.cameraTransform.translation.y - hit.columns.3.y
        } else if !ARWorldTrackingConfiguration.isSupported {
            // Simulator / no-AR fallback so the UI flow stays testable.
            floorTransform = matrix_identity_float4x4
            eyeHeight = 1.4
        } else {
            appModel.lastMessage = "Move the device over the floor and tap again"
            return
        }

        Task { await placeScene(floorTransform: floorTransform, eyeHeight: eyeHeight) }
    }

    private func placeScene(floorTransform: simd_float4x4, eyeHeight: Float) async {
        guard let arView else { return }

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
        let newHierarchy = SceneHierarchy(floorTransform: floorTransform, content: content)
        arView.scene.addAnchor(newHierarchy.originAnchor)
        hierarchy = newHierarchy

        appModel.eyeHeight = eyeHeight
        appModel.heightNudge = 0
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

    private func floorRaycast(at point: CGPoint) -> simd_float4x4? {
        guard let arView else { return nil }
        guard let query = arView.makeRaycastQuery(from: point,
                                                  allowing: .estimatedPlane,
                                                  alignment: .horizontal) else { return nil }
        return arView.session.raycast(query).first?.worldTransform
    }

    // MARK: - ARExperienceActions

    func recenter() {
        hierarchy?.recenter()
    }

    func recalibrate() {
        if let arView, let old = hierarchy {
            arView.scene.removeAnchor(old.originAnchor)
        }
        hierarchy = nil
        appModel.phase = .calibrating
        appModel.lastMessage = "Aim at the floor and tap"
        startSession()
    }

    func nudgeHeight(_ delta: Float) {
        hierarchy?.nudgeHeight(delta)
        appModel.heightNudge += delta
        appModel.eyeHeight -= delta   // raising the scene lowers the apparent eye height
    }

    // MARK: - ARSessionDelegate (debug read-outs)

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
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
        guard appModel.showDebugOverlay, lastFrameTimestamp != 0 else { return }
        let dt = link.timestamp - lastFrameTimestamp
        if dt > 0 { appModel.fps = 1.0 / dt }
    }
}
