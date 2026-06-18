//
//  ManifestLevelProvider.swift
//  UP_AR (UniPlace)
//
//  Loads ONE scene from the combined manifest: resolves the shared layers + the selected scene's
//  layers, runs each through the matching material processor, assembles a content root, and offsets the
//  scene so its spawn empty lands on the calibrated floor origin. A phone can't hold both scenes at
//  once, so only the chosen scene's layers are resolved. Falls back to the placeholder room when the
//  manifest/assets are missing, so the app keeps running before real content exists.
//

import Foundation
import RealityKit

@MainActor
struct ManifestLevelProvider: LevelProvider {
    let sceneId: String
    let manifestName: String
    let fallback: LevelProvider
    private let locator = LevelResourceLocator()

    init(sceneId: String, manifestName: String = "LevelManifest", fallback: LevelProvider) {
        self.sceneId = sceneId
        self.manifestName = manifestName
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
        guard let scene = manifest.scene(id: sceneId) else {
            throw LevelResourceLocator.LocatorError.missing("scene '\(sceneId)' in \(manifestName)")
        }
        let materials = manifest.materials ?? .empty
        let pipeline = MaterialPipeline.standard()

        let sceneRoot = Entity()
        sceneRoot.name = "SceneRoot"

        // Reflective layers (glass/reflect/water) attach receivers to one shared IBL built under
        // sceneRoot; the resolver lets the IBL find an optional environment image in the bundle.
        let context = MaterialContext(worldRoot: sceneRoot,
                                      resolve: { [locator] name in try? locator.resolve(name) })

        // Shared layers first (skybox), then the scene's own layers — manifest order is honoured so a
        // `probes` layer can precede the reflective layers that may later consume it.
        for layer in manifest.shared + scene.layers {
            let url = try locator.resolve(layer.file)
            let entity = try await Entity(contentsOf: url)
            entity.name = layer.file
            await pipeline.process(entity, type: layer.type,
                                   params: materials.params(for: layer.type), context: context)
            sceneRoot.addChild(entity)
            MemoryDiagnostics.log("loaded layer \(layer.file) [\(layer.type)]")
        }

        // Spawn: shift the whole scene so the spawn empty sits at the calibrated floor origin.
        // Orientation stays real (the device's heading), so only the translation is applied.
        if let start = sceneRoot.findEntity(named: scene.spawn.entity) {
            sceneRoot.position = -start.position(relativeTo: sceneRoot)
        } else {
            TimingDiagnostics.log("spawn entity '\(scene.spawn.entity)' not found — scene left at origin")
        }

        let content = Entity()
        content.name = "LevelContent"
        content.addChild(sceneRoot)
        return content
    }
}
