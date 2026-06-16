//
//  LevelProvider.swift
//  UP_AR (UniPlace)
//
//  Phase-2 seam: the rest of the app only knows it receives a `sceneContent` Entity. In Phase 2 this
//  is replaced by a manifest-driven loader (porting AVP's LevelLoader); nothing else has to change.
//

import RealityKit

@MainActor
protocol LevelProvider {
    func makeContent() async throws -> Entity
}

/// Phase 1 content: a placeholder cube on a floor grid.
struct PlaceholderLevelProvider: LevelProvider {
    func makeContent() async throws -> Entity {
        PlaceholderScene.build()
    }
}
