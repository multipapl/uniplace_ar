//
//  PlaceholderScene.swift
//  UP_AR (UniPlace)
//
//  Phase-1 placeholder content: a small unlit test room (floor + walls + corner pillars + a centre
//  cube) used to exercise the portal feel, physical walking, teleport and recenter without any real
//  content or asset pipeline. The floor carries a CollisionComponent so teleport raycasts have a
//  surface to hit; walls/pillars are visual parallax cues only. Everything is unlit so it reads
//  correctly in the portal (no scene lights), matching the renderer direction.
//

import RealityKit
import UIKit

enum PlaceholderScene {
    /// Floor is `roomSize` × `roomSize` metres; walls are `wallHeight` tall.
    private static let roomSize: Float = 8
    private static let wallHeight: Float = 3

    static func build() -> Entity {
        let root = Entity()
        root.name = "PlaceholderScene"

        root.addChild(makeFloor())
        addWalls(to: root)
        addCornerPillars(to: root)
        root.addChild(makeCube())

        return root
    }

    // MARK: - Pieces

    /// Visible floor plus a thin collision box (top at y = 0) so teleport hit-tests land on it.
    private static func makeFloor() -> ModelEntity {
        let floor = ModelEntity(
            mesh: .generatePlane(width: roomSize, depth: roomSize),
            materials: [unlit(UIColor(white: 0.20, alpha: 1))]
        )
        floor.name = "Floor"

        // Thin collider sunk so its top face sits at the floor plane (y = 0); teleport drops Y anyway.
        let thickness: Float = 0.04
        let collider = ShapeResource
            .generateBox(width: roomSize, height: thickness, depth: roomSize)
            .offsetBy(translation: [0, -thickness / 2, 0])
        floor.collision = CollisionComponent(shapes: [collider])
        return floor
    }

    private static func addWalls(to root: Entity) {
        let half = roomSize / 2
        let t: Float = 0.05
        let y = wallHeight / 2

        // North wall is accent-coloured so orientation is readable; the rest are neutral.
        let north = makeBox(width: roomSize, height: wallHeight, depth: t,
                            color: UIColor(red: 0.20, green: 0.42, blue: 0.62, alpha: 1))
        north.position = [0, y, -half]
        root.addChild(north)

        let south = makeBox(width: roomSize, height: wallHeight, depth: t,
                            color: UIColor(white: 0.34, alpha: 1))
        south.position = [0, y, half]
        root.addChild(south)

        let west = makeBox(width: t, height: wallHeight, depth: roomSize,
                           color: UIColor(white: 0.34, alpha: 1))
        west.position = [-half, y, 0]
        root.addChild(west)

        let east = makeBox(width: t, height: wallHeight, depth: roomSize,
                           color: UIColor(white: 0.34, alpha: 1))
        east.position = [half, y, 0]
        root.addChild(east)
    }

    /// Four coloured corner pillars give strong parallax + obvious teleport landmarks.
    private static func addCornerPillars(to root: Entity) {
        let inset: Float = roomSize / 2 - 0.6
        let height: Float = 1.4
        let colors: [UIColor] = [
            UIColor(red: 0.85, green: 0.30, blue: 0.30, alpha: 1),
            UIColor(red: 0.30, green: 0.75, blue: 0.45, alpha: 1),
            UIColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1),
            UIColor(red: 0.65, green: 0.40, blue: 0.85, alpha: 1)
        ]
        let corners: [SIMD2<Float>] = [[-inset, -inset], [inset, -inset],
                                       [-inset, inset], [inset, inset]]
        for (corner, color) in zip(corners, colors) {
            let pillar = makeBox(width: 0.16, height: height, depth: 0.16, color: color)
            pillar.position = [corner.x, height / 2, corner.y]
            root.addChild(pillar)
        }
    }

    /// Centre cube: 40 cm, raised half its height so it rests ON the floor (y = 0). Scale reference.
    private static func makeCube() -> ModelEntity {
        let side: Float = 0.4
        let cube = makeBox(width: side, height: side, depth: side,
                           color: UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1))
        cube.name = "Cube"
        cube.position = [0, side / 2, 0]
        return cube
    }

    // MARK: - Helpers

    private static func makeBox(width: Float, height: Float, depth: Float, color: UIColor) -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(width: width, height: height, depth: depth),
            materials: [unlit(color)]
        )
    }

    /// Double-sided unlit material so interior wall faces stay visible and baked colour shows as-is.
    private static func unlit(_ color: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: color)
        material.faceCulling = .none
        return material
    }
}
