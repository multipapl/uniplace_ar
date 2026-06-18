//
//  ReflectionEnvironment.swift
//  UP_AR (UniPlace)
//
//  Per-probe image-based lighting for the reflective layers (reflect, glass, water). The `probes` layer
//  is a set of invisible planes placed where a 360° reflection was captured; each plane's name maps to
//  an extracted equirectangular env map (Content/ProbesTextures + probes.json, produced by the asset
//  optimizer). We build ONE IBL light per probe, then point each reflective model at its NEAREST probe.
//
//  RealityKit needs a real image to build an EnvironmentResource — pixels can't be read back from a
//  loaded texture — which is why the optimizer extracts the probe maps to files. Two-probe distance
//  blending (AVP) is deferred; see docs/backlog.md.
//

import CoreGraphics
import Foundation
import ImageIO
import RealityKit
import simd

@MainActor
final class ReflectionEnvironment {
    private struct Probe {
        let position: SIMD3<Float>
        let light: Entity
    }

    private var probes: [Probe] = []
    private weak var worldRoot: Entity?

    /// Build one IBL light per probe plane present in the probes layer. `mapping` is plane name → env
    /// image file (probes.json). Planes not in this scene are simply absent and skipped.
    func registerProbes(from probesScene: Entity,
                        mapping: [String: String],
                        worldRoot: Entity,
                        resolve: (String) -> URL?,
                        intensityExponent: Float) async {
        self.worldRoot = worldRoot
        for (planeName, textureFile) in mapping {
            guard let plane = probesScene.findEntity(named: planeName),
                  let url = resolve(textureFile),
                  let image = loadCGImage(from: url),
                  let environment = try? await EnvironmentResource(equirectangular: image, withName: planeName)
            else { continue }

            let light = Entity()
            light.name = "ProbeIBL_\(planeName)"
            var component = ImageBasedLightComponent(source: .single(environment),
                                                     intensityExponent: intensityExponent)
            // Probe planes are authored as world-orientation controls, so the IBL must inherit the
            // plane's yaw (rotating a probe in the DCC rotates its reflected panorama).
            component.inheritsRotation = true
            light.components.set(component)
            let position = plane.position(relativeTo: worldRoot)
            light.setOrientation(plane.orientation(relativeTo: worldRoot), relativeTo: worldRoot)
            light.setPosition(position, relativeTo: worldRoot)
            worldRoot.addChild(light)
            probes.append(Probe(position: position, light: light))
        }
        MemoryDiagnostics.log("reflection: \(probes.count) probe IBL(s) registered")
    }

    /// Point a model at the nearest probe's IBL so it receives that reflection. No-op without probes.
    func applyReceiver(to entity: Entity) {
        guard let worldRoot, !probes.isEmpty else { return }
        let target = receiverPosition(for: entity, in: worldRoot)
        guard let nearest = probes.min(by: {
            simd_distance($0.position, target) < simd_distance($1.position, target)
        }) else { return }
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: nearest.light))
    }

    private func receiverPosition(for entity: Entity, in worldRoot: Entity) -> SIMD3<Float> {
        let bounds = entity.visualBounds(recursive: false, relativeTo: worldRoot)
        if bounds.min.x.isFinite, bounds.max.x.isFinite {
            return bounds.center
        }
        return entity.position(relativeTo: worldRoot)
    }

    private func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // Keep floating-point data for .hdr/.exr maps so highlights stay bright; harmless for 8-bit jpg.
        let options: [CFString: Any] = [kCGImageSourceShouldAllowFloat: true]
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }
}
