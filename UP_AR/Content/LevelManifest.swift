//
//  LevelManifest.swift
//  UP_AR (UniPlace)
//
//  The global, human-editable level config: WHAT loads, HOW it renders (each layer names its
//  processing `type`), and WHAT relates to what (spawn). Deliberately holds NO material knob values —
//  those live in MaterialConfig, grouped by type. Data-driven so a non-programmer can edit it.
//

import Foundation

struct LevelManifest: Decodable {
    /// One loaded layer: a file plus the processing type that decides how it is rendered.
    struct Layer: Decodable {
        let file: String
        let type: String
    }

    /// Where the viewer starts: the name of an empty in the scene (currently in the navmesh layer)
    /// that is moved onto the calibrated floor origin at load time.
    struct Spawn: Decodable {
        let entity: String
    }

    let id: String
    let title: String
    let spawn: Spawn
    let layers: [Layer]
}
