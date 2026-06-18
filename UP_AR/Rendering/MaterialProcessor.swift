//
//  MaterialProcessor.swift
//  UP_AR (UniPlace)
//
//  One processing type for a loaded layer (unlit, navmesh, glass, reflect…). Each type is its own
//  file conforming to this protocol; MaterialPipeline holds the registry. Adding a type is a new file
//  + one registration line — no edits to the loader or existing processors.
//

import Foundation
import RealityKit

/// Shared, per-load state handed to every processor. A reference type so coupled types can agree on
/// the same state: reflect/glass/water all attach receivers to the one shared `reflection` IBL, and a
/// `probes` layer can stash its anchors here for a later per-probe upgrade. The closures keep the
/// processors decoupled from the bundle/loader.
@MainActor
final class MaterialContext {
    /// Root the whole level is assembled under — where shared light entities (IBL) are attached.
    let worldRoot: Entity
    /// Resolve a bundled resource by name (e.g. an environment image), or nil when absent.
    let resolve: (String) -> URL?
    /// Shared image-based-light environment for the reflective layers.
    let reflection = ReflectionEnvironment()
    /// The `probes` layer's anchor entities, once that layer has been processed. Unused by the shared
    /// IBL path; reserved for per-probe nearest-probe blending when env maps land.
    var probesScene: Entity?

    init(worldRoot: Entity, resolve: @escaping (String) -> URL? = { _ in nil }) {
        self.worldRoot = worldRoot
        self.resolve = resolve
    }
}

@MainActor
protocol MaterialProcessor {
    /// Process one loaded layer root in place: materials, collision, visibility, etc.
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async
}
