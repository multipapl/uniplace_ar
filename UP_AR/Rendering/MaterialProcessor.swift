//
//  MaterialProcessor.swift
//  UP_AR (UniPlace)
//
//  One processing type for a loaded layer (unlit, navmesh, later glass/reflect…). Each type is its
//  own file conforming to this protocol; MaterialPipeline holds the registry. Adding a type is a new
//  file + one registration line — no edits to the loader or existing processors.
//

import RealityKit

/// Shared state handed to every processor. Empty today; reserved for coupled types later (e.g. a
/// shared reflection environment that reflect + glass must agree on), so the protocol never changes.
struct MaterialContext {}

@MainActor
protocol MaterialProcessor {
    /// Process one loaded layer root in place: materials, collision, visibility, etc.
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async
}
