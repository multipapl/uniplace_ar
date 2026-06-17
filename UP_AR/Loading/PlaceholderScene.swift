//
//  PlaceholderScene.swift
//  UP_AR (UniPlace)
//
//  Runtime SAFETY-NET content: shown by PlaceholderLevelProvider whenever the real manifest content
//  can't be loaded, so the app never lands the user in an empty void. A small lit room (floor + walls
//  + a centre cube) with its own lights — deliberately NOT unlit, so it reads as obviously different
//  from real baked content — plus a billboarded "PLACEHOLDER" label floating over the cube that always
//  faces the viewer. The floor carries a CollisionComponent so teleport raycasts have a surface to hit.
//
//  Note: the portal background is a flat colour with no image-based lighting and ARKit light
//  estimation is off (see PortalEnvironment), so SimpleMaterial needs the explicit lights added here.
//

import RealityKit
import UIKit

enum PlaceholderScene {
    /// Floor is `roomSize` × `roomSize` metres; walls are `wallHeight` tall.
    private static let roomSize: Float = 8
    private static let wallHeight: Float = 3
    private static let cubeSide: Float = 0.4

    static func build() -> Entity {
        let root = Entity()
        root.name = "PlaceholderScene"

        addLights(to: root)
        root.addChild(makeFloor())
        addWalls(to: root)
        root.addChild(makeCube())
        root.addChild(makeLabel())

        return root
    }

    // MARK: - Lighting

    /// A key light from above-front and a dimmer fill from the opposite side so no face goes pure
    /// black. Intensities (lux) are eyeballed for the flat portal background — tune freely.
    private static func addLights(to root: Entity) {
        root.addChild(makeDirectionalLight(direction: [0.4, -1, 0.35], intensity: 4000))
        root.addChild(makeDirectionalLight(direction: [-0.4, -0.5, -0.35], intensity: 1200))
    }

    private static func makeDirectionalLight(direction: SIMD3<Float>, intensity: Float) -> Entity {
        let entity = Entity()
        entity.components.set(DirectionalLightComponent(color: .white, intensity: intensity))
        // A directional light emits along the entity's forward (-Z); aim it down `direction`.
        entity.look(at: direction, from: .zero, relativeTo: nil)
        return entity
    }

    // MARK: - Pieces

    /// Visible floor plus a thin collision box (top at y = 0) so teleport hit-tests land on it.
    private static func makeFloor() -> ModelEntity {
        let floor = ModelEntity(
            mesh: .generatePlane(width: roomSize, depth: roomSize),
            materials: [lit(UIColor(white: 0.22, alpha: 1))]
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

        for (w, d, x, z) in [(roomSize, t, Float(0), half),   // south
                             (t, roomSize, -half, Float(0)),   // west
                             (t, roomSize, half, Float(0))] {  // east
            let wall = makeBox(width: w, height: wallHeight, depth: d,
                               color: UIColor(white: 0.36, alpha: 1))
            wall.position = [x, y, z]
            root.addChild(wall)
        }
    }

    /// Centre cube: raised half its height so it rests ON the floor (y = 0). Scale reference.
    private static func makeCube() -> ModelEntity {
        let cube = makeBox(width: cubeSide, height: cubeSide, depth: cubeSide,
                           color: UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1))
        cube.name = "Cube"
        cube.position = [0, cubeSide / 2, 0]
        return cube
    }

    /// Billboarded text floating above the cube; BillboardComponent (iOS 18+) keeps it facing the
    /// viewer from any angle. Unlit white so the label stays legible regardless of the lighting.
    private static func makeLabel() -> Entity {
        let container = Entity()
        container.name = "PlaceholderLabel"
        container.position = [0, cubeSide + 0.8, 0]
        container.components.set(BillboardComponent())

        let mesh = MeshResource.generateText(
            "PLACEHOLDER",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.14, weight: .semibold),
            alignment: .center
        )
        let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        // generateText anchors at the baseline-left corner; recentre on the container.
        let bounds = mesh.bounds
        text.position = [-bounds.center.x, -bounds.center.y, 0]
        container.addChild(text)
        return container
    }

    // MARK: - Helpers

    private static func makeBox(width: Float, height: Float, depth: Float, color: UIColor) -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(width: width, height: height, depth: depth),
            materials: [lit(color)]
        )
    }

    /// Matte lit material with a procedurally generated 2-tone checker (the colour vs a darker shade of
    /// it), so each surface keeps its identity colour but reads as an obvious placeholder grid. The
    /// checker is generated in code — no asset files — since this scene is throwaway scaffolding.
    private static func lit(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        if let texture = checkerTexture(color) {
            material.baseColor = .init(tint: .white, texture: .init(texture))
        } else {
            material.baseColor = .init(tint: color)
        }
        material.roughness = 0.85
        material.metallic = 0.0
        return material
    }

    /// A `squares`×`squares` checkerboard of `color` alternating with a darkened shade of it.
    private static func checkerTexture(_ color: UIColor, dim: Int = 256, squares: Int = 8) -> TextureResource? {
        let dark = darkened(color, by: 0.45)
        let size = CGSize(width: dim, height: dim)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let s = dim / squares
            for row in 0..<squares {
                for col in 0..<squares {
                    ((row + col).isMultiple(of: 2) ? color : dark).setFill()
                    ctx.fill(CGRect(x: col * s, y: row * s, width: s, height: s))
                }
            }
        }
        guard let cg = image.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    private static func darkened(_ color: UIColor, by factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: b * factor, alpha: a)
    }
}
