//
//  MaterialConfig.swift
//  UP_AR (UniPlace)
//
//  All material/processing knobs, grouped by layer `type` (e.g. "unlit", "navmesh", "glass").
//  Decoded from LevelManifest.json's `materials` section. A glass pipeline renders all glass the same
//  way; its opacity belongs in the type-level knobs, not on individual layer entries.
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

        // clock (runtime texture synced to device local time)
        var clockUVIndex: Int?
        var clockUVRect: [Float]?
        var clockTint: [Float]?
        var clockFlipU: Bool?
        var clockFlipV: Bool?

        // homepod (unlit body + looping screen video + spatial-music emitter)
        var homepodScreenEntity: String?   // mesh that receives the looping screen video
        var homepodScreenVideo: String?     // opaque looped video file driving the screen
        var homepodBodyEntity: String?      // body mesh; the music emitter sits at its bounds centre
        // spatial-music playback tuning, carried to the emitter for the music controller to consume
        var musicShuffle: Bool?
        var musicDefaultVolume: Float?
        var musicGainBoostDB: Float?        // loudness calibration added on top of user volume
        var musicReverbPreset: String?      // RealityKit reverb preset; "none"/omit disables reverb
        var musicReverbLevelDB: Float?

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
