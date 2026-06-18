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
    /// New knobs are added here as new optional fields, so old configs keep decoding.
    struct Params: Decodable {
        // navmesh
        var debugVisible: Bool?

        // skybox
        var skyBrightness: Float?
        var skyTint: [Float]?
        var skyOpacity: Float?

        // translucent
        var translucentAlphaCutoff: Float?
        var translucentAlphaFromOpacity: Bool?
        var translucentBaseColorUVIndex: Int?
        var translucentAlphaUVIndex: Int?

        // emission
        var emissionBrightness: Float?
        var emissionTint: [Float]?

        // fire (looping alpha video material)
        var fireVideo: String?

        // curtains
        var curtainOpacity: Float?
        var curtainTint: [Float]?
        var curtainBrightness: Float?

        // glass
        var glassOpacity: Float?
        var glassRoughness: Float?
        var glassSpecular: Float?
        var glassClearcoat: Float?
        var glassClearcoatRoughness: Float?

        // reflect
        var reflectBaseColorUVIndex: Int?
        var reflectMaterialUVIndex: Int?
        var reflectMaterialPacking: String?

        // shared reflection environment (read by glass/reflect/water — first to ask wins)
        var reflectionEnvironment: String?
        var reflectionEnvironmentName: String?
        var reflectionIntensityExponent: Float?
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
