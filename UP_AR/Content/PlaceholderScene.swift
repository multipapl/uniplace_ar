//
//  PlaceholderScene.swift
//  UP_AR (UniPlace)
//
//  Phase-1 placeholder content: a cube resting on the floor + a faint floor grid for spatial
//  reference. The floor carries a CollisionComponent so teleport taps can hit it.
//

import RealityKit
import UIKit

enum PlaceholderScene {
    static func build() -> Entity {
        let root = Entity()
        root.name = "PlaceholderScene"

        // Cube: 0.3 m, raised half its height so it rests ON the floor (y = 0).
        let side: Float = 0.3
        var cubeMaterial = PhysicallyBasedMaterial()
        cubeMaterial.baseColor = .init(tint: UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1))
        cubeMaterial.roughness = 0.4
        cubeMaterial.metallic = 0.0
        let cube = ModelEntity(mesh: .generateBox(size: side, cornerRadius: 0.01),
                               materials: [cubeMaterial])
        cube.position = [0, side / 2, 0]
        cube.name = "Cube"
        root.addChild(cube)

        // Floor: a thin plane the teleport raycast can hit.
        let floorSize: Float = 8
        let floor = ModelEntity(mesh: .generatePlane(width: floorSize, depth: floorSize),
                                materials: [UnlitMaterial(color: UIColor(white: 0.32, alpha: 1))])
        floor.name = "Floor"
        floor.generateCollisionShapes(recursive: false)
        root.addChild(floor)

        // Grid lines, for a sense of motion when walking.
        root.addChild(makeGrid(size: floorSize, spacing: 0.5))

        return root
    }

    private static func makeGrid(size: Float, spacing: Float) -> Entity {
        let grid = Entity()
        grid.name = "Grid"
        let half = size / 2
        let thickness: Float = 0.005
        let material = UnlitMaterial(color: UIColor(white: 0.5, alpha: 1))

        var offset = -half
        while offset <= half {
            let alongZ = ModelEntity(
                mesh: .generateBox(width: thickness, height: 0.001, depth: size),
                materials: [material])
            alongZ.position = [offset, 0.001, 0]
            grid.addChild(alongZ)

            let alongX = ModelEntity(
                mesh: .generateBox(width: size, height: 0.001, depth: thickness),
                materials: [material])
            alongX.position = [0, 0.001, offset]
            grid.addChild(alongX)

            offset += spacing
        }
        return grid
    }
}
