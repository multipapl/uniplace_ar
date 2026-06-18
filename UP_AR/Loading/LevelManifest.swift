//
//  LevelManifest.swift
//  UP_AR (UniPlace)
//
//  The single settings file for content + rendering. One JSON holds three sections:
//    • `shared`    — layers loaded for every scene (e.g. the skybox);
//    • `scenes`    — the selectable scenes (floor / terrace), each with its own spawn + layers;
//    • `materials` — material knobs grouped by processing `type` (scene-independent; glass is glass
//                    everywhere). Folded in here on purpose — there is no separate MaterialConfig file.
//
//  A phone can't hold both scenes at once, so the loader resolves ONE scene at a time (shared + that
//  scene's layers). Data-driven so a non-programmer can edit it.
//

import Foundation

struct LevelManifest: Decodable {
    /// One loaded layer: a file plus the processing type that decides how it is rendered.
    struct Layer: Decodable {
        let file: String
        let type: String
    }

    /// Where the viewer starts: the name of an empty in the scene (currently in the navmesh layer)
    /// moved onto the calibrated floor origin at load time.
    struct Spawn: Decodable {
        let entity: String
    }

    /// One selectable scene (e.g. the floor or the terrace).
    struct Scene: Decodable {
        let id: String
        let title: String
        let spawn: Spawn
        let layers: [Layer]
    }

    /// Layers common to every scene (skybox). Loaded alongside whichever scene is selected.
    let shared: [Layer]
    let scenes: [Scene]
    /// Material knobs by type. Optional so a bare manifest still decodes; absent ⇒ empty defaults.
    let materials: MaterialConfig?

    func scene(id: String) -> Scene? { scenes.first { $0.id == id } }
}
