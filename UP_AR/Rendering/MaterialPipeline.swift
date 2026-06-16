//
//  MaterialPipeline.swift
//  UP_AR (UniPlace)
//
//  Thin dispatcher over a registry of MaterialProcessors keyed by the manifest layer `type`. This is
//  the single place that knows which types exist; the processing logic lives in the per-type files.
//

import RealityKit

@MainActor
final class MaterialPipeline {
    private let processors: [String: MaterialProcessor]

    init(processors: [String: MaterialProcessor]) {
        self.processors = processors
    }

    /// The layer-processing types the app supports. Add a type = add a file + one line here.
    static func standard() -> MaterialPipeline {
        MaterialPipeline(processors: [
            "unlit": UnlitProcessor(),
            "navmesh": NavmeshProcessor()
        ])
    }

    func process(_ entity: Entity,
                 type: String,
                 params: MaterialConfig.Params,
                 context: MaterialContext) async {
        guard let processor = processors[type] else {
            TimingDiagnostics.log("unknown layer type '\(type)' — left unprocessed")
            return
        }
        await processor.process(entity, params: params, context: context)
    }
}
