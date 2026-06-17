//
//  MaterialConfig.swift
//  UP_AR (UniPlace)
//
//  All material/processing knobs, grouped by layer `type` (e.g. "unlit", "navmesh", later "glass").
//  Kept separate from LevelManifest on purpose: the manifest says what/how loads, this holds the
//  tunable values. A glass pipeline renders all glass the same way; its opacity belongs here, not in
//  the manifest. Human-editable JSON, one block per type.
//

import Foundation

struct MaterialConfig: Decodable {
    /// Union of every knob across all types; each processor reads only the fields it cares about.
    /// New knobs (glassOpacity, tint, …) are added here as new optional fields.
    struct Params: Decodable {
        var debugVisible: Bool?
    }

    private let byType: [String: Params]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        byType = (try? container.decode([String: Params].self)) ?? [:]
    }

    private init() { byType = [:] }

    /// Knobs for a layer type, or empty defaults when the type is absent from the config.
    func params(for type: String) -> Params { byType[type] ?? Params() }

    static let empty = MaterialConfig()
}
