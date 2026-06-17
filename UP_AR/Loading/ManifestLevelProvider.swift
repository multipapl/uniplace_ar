//
//  ManifestLevelProvider.swift
//  UP_AR (UniPlace)
//
//  Loads a level from its manifest: resolves each layer, runs it through the matching material
//  processor, assembles a content root, and offsets the scene so the spawn empty lands on the
//  calibrated floor origin. Falls back to the placeholder room when no manifest/assets are present,
//  so the app keeps running before real content exists.
//

import Foundation
import RealityKit

@MainActor
struct ManifestLevelProvider: LevelProvider {
    let manifestName: String
    let materialConfigName: String
    let fallback: LevelProvider
    private let locator = LevelResourceLocator()

    init(manifestName: String = "LevelManifest",
         materialConfigName: String = "MaterialConfig",
         fallback: LevelProvider) {
        self.manifestName = manifestName
        self.materialConfigName = materialConfigName
        self.fallback = fallback
    }

    func makeContent() async throws -> Entity {
        do {
            return try await loadFromManifest()
        } catch {
            TimingDiagnostics.log("manifest content unavailable (\(error.localizedDescription)) — using placeholder")
            return try await fallback.makeContent()
        }
    }

    private func loadFromManifest() async throws -> Entity {
        let manifest = try locator.loadManifest(named: manifestName)
        let materials = (try? locator.loadMaterialConfig(named: materialConfigName)) ?? .empty
        let pipeline = MaterialPipeline.standard()
        let context = MaterialContext()

        let sceneRoot = Entity()
        sceneRoot.name = "SceneRoot"

        for layer in manifest.layers {
            let url = try locator.resolve(layer.file)
            let entity = try await Entity(contentsOf: url)
            entity.name = layer.file
            await pipeline.process(entity, type: layer.type,
                                   params: materials.params(for: layer.type), context: context)
            sceneRoot.addChild(entity)
            MemoryDiagnostics.log("loaded layer \(layer.file) [\(layer.type)]")
        }

        // Spawn: shift the whole scene so the StartPosition empty sits at the calibrated floor origin.
        // Orientation stays real (the device's heading), so only the translation is applied.
        if let start = sceneRoot.findEntity(named: manifest.spawn.entity) {
            sceneRoot.position = -start.position(relativeTo: sceneRoot)
        } else {
            TimingDiagnostics.log("spawn entity '\(manifest.spawn.entity)' not found — scene left at origin")
        }

        let content = Entity()
        content.name = "LevelContent"
        content.addChild(sceneRoot)
        return content
    }
}
