//
//  ARViewContainer.swift
//  UP_AR (UniPlace)
//
//  Bridges the ARView into SwiftUI and owns the session controller for its lifetime. Kept thin:
//  all session/tap/scene logic lives in ARSessionController (the coordinator).
//

import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @Environment(AppModel.self) private var appModel

    func makeCoordinator() -> ARSessionController {
        ARSessionController(appModel: appModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                            cameraMode: .ar,
                            automaticallyConfigureSession: false)
        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ARSessionController) {
        coordinator.pause()
    }
}
