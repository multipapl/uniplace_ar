//
//  ARViewContainer.swift
//  UP_AR (UniPlace)
//
//  Bridges the ARView into SwiftUI and owns the session controller for its lifetime. Kept thin:
//  all session/tap/scene logic lives in ARSessionController (the coordinator).
//
//  The ARView is hosted inside a UIViewController (not a bare UIViewRepresentable) so it takes part
//  in the window's rotation lifecycle. A detached representable view doesn't get rotation-transition
//  coordination, which made the first portrait↔landscape change show a stretched/cropped camera feed
//  for a couple of seconds. A view controller resizes its root ARView *within* the transition, so the
//  feed and render target update cleanly on the very first rotation.
//

import RealityKit
import SwiftUI
import UIKit

struct ARViewContainer: UIViewControllerRepresentable {
    @Environment(AppModel.self) private var appModel

    func makeCoordinator() -> ARSessionController {
        ARSessionController(appModel: appModel)
    }

    func makeUIViewController(context: Context) -> ARViewController {
        TimingDiagnostics.log("ARView makeUIViewController begin")
        let controller = ARViewController()
        controller.applyRenderScale(appModel.renderScale)
        context.coordinator.attach(to: controller.arView)
        TimingDiagnostics.log("ARView attached")
        return controller
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        uiViewController.applyRenderScale(appModel.renderScale)
    }

    static func dismantleUIViewController(_ uiViewController: ARViewController,
                                          coordinator: ARSessionController) {
        coordinator.pause()
    }
}

/// Minimal host whose root view *is* the ARView, so rotation resizing is driven by the
/// view-controller transition rather than an after-the-fact SwiftUI layout pass.
final class ARViewController: UIViewController {
    let arView = ARView(frame: .zero,
                        cameraMode: .ar,
                        automaticallyConfigureSession: false)
    private var appliedRenderScale: Double?

    override func loadView() {
        TimingDiagnostics.log("ARView created")
        view = arView
    }

    func applyRenderScale(_ renderScale: Double) {
        let clamped = min(max(renderScale, AppModel.minRenderScale), AppModel.maxRenderScale)
        guard appliedRenderScale != clamped else { return }

        let screenScale = view.window?.screen.scale ?? UIScreen.main.scale
        arView.contentScaleFactor = screenScale * clamped
        appliedRenderScale = clamped
        TimingDiagnostics.log(String(format: "render scale %.2f", clamped))
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.arView.frame = CGRect(origin: .zero, size: size)
        })
    }
}
