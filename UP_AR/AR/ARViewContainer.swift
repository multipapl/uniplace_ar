//
//  ARViewContainer.swift
//  UP_AR (UniPlace)
//
//  Bridges the ARView into SwiftUI and owns the session controller for its lifetime. Kept thin:
//  all session/tap/scene logic lives in ARSessionController (the coordinator).
//

import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    @Environment(AppModel.self) private var appModel

    func makeCoordinator() -> ARSessionController {
        ARSessionController(appModel: appModel)
    }

    func makeUIView(context: Context) -> ARView {
        TimingDiagnostics.log("ARView makeUIView begin")
        let arView = ARView(frame: .zero,
                            cameraMode: .ar,
                            automaticallyConfigureSession: false)
        TimingDiagnostics.log("ARView created")
        context.coordinator.attach(to: arView)
        TimingDiagnostics.log("ARView attached")
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ARSessionController) {
        coordinator.pause()
    }
}
