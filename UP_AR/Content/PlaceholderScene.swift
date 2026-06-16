//
//  PlaceholderScene.swift
//  UP_AR (UniPlace)
//
//  Phase-1 placeholder content: one opaque 1 m cube for scale and drift checks.
//

import RealityKit
import UIKit

enum PlaceholderScene {
    static func build() -> Entity {
        let root = Entity()
        root.name = "PlaceholderScene"

        // Cube: 40 cm, raised half its height so it rests ON the floor (y = 0).
        let side: Float = 0.4
        var cubeMaterial = PhysicallyBasedMaterial()
        cubeMaterial.baseColor = .init(tint: UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1.0))
        cubeMaterial.roughness = 0.4
        cubeMaterial.metallic = 0.0
        let cube = ModelEntity(mesh: .generateBox(size: side, cornerRadius: 0.01),
                               materials: [cubeMaterial])
        cube.position = [0, side / 2, 0]
        cube.name = "Cube"
        root.addChild(cube)

        return root
    }
}
