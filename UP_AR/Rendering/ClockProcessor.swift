//
//  ClockProcessor.swift
//  UP_AR (UniPlace)
//
//  Runtime digital clock overlay. The USDZ supplies only the transparent display planes/UVs; this
//  processor replaces every material with a generated unlit texture showing the device's local time.
//

import CoreGraphics
import Foundation
import RealityKit
import UIKit

struct ClockDisplayComponent: Component {
    let controller: ClockDisplayController
}

@MainActor
struct ClockProcessor: MaterialProcessor {
    func process(_ entity: Entity, params: MaterialConfig.Params, context: MaterialContext) async {
        removeSceneLighting(entity)

        let controller = ClockDisplayController(root: entity, params: params)
        entity.components.set(ClockDisplayComponent(controller: controller))
        controller.start()
    }
}

@MainActor
final class ClockDisplayController {
    private let params: MaterialConfig.Params
    private let targets: [Entity]
    private var updateTask: Task<Void, Never>?
    private var lastFrameKey: String?

    init(root: Entity, params: MaterialConfig.Params) {
        self.params = params
        self.targets = Self.modelEntities(in: root)
    }

    deinit {
        updateTask?.cancel()
    }

    func start() {
        guard updateTask == nil else { return }

        updateMaterialIfNeeded(force: true)
        TimingDiagnostics.log("clock layer: started \(targets.count) mesh(es)")

        updateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.updateMaterialIfNeeded(force: false)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateMaterialIfNeeded(force: Bool) {
        let frame = ClockDisplayFrame(date: Date())
        guard force || frame.key != lastFrameKey else { return }

        do {
            let image = try ClockTextureRenderer.render(
                frame: frame,
                uvRect: params.clockTextureRect,
                flipU: params.clockFlipU ?? false,
                flipV: params.clockFlipV ?? false,
                tint: params.clockTintColor
            )
            let texture = try TextureResource(
                image: image,
                options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .none)
            )
            apply(material: Self.clockMaterial(texture: texture, uvIndex: params.clockUVIndex ?? 1))
            lastFrameKey = frame.key
        } catch {
            TimingDiagnostics.log("clock layer: texture update failed (\(error.localizedDescription))")
            apply(material: Self.fallbackClockMaterial())
        }
    }

    private func apply(material: any RealityKit.Material) {
        for entity in targets {
            guard var model = entity.components[ModelComponent.self] else { continue }
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components[ModelComponent.self] = model
        }
    }

    private static func clockMaterial(texture: TextureResource, uvIndex: Int) -> UnlitMaterial {
        var baseTexture = PhysicallyBasedMaterial.Texture(texture)
        baseTexture.uvIndex = uvIndex

        var opacityTexture = PhysicallyBasedMaterial.Texture(texture)
        opacityTexture.uvIndex = uvIndex

        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .white, texture: baseTexture)
        material.blending = .transparent(opacity: .init(scale: 1, texture: opacityTexture))
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func fallbackClockMaterial() -> UnlitMaterial {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .systemCyan.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: .init(scale: 0.55))
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func modelEntities(in entity: Entity) -> [Entity] {
        var entities: [Entity] = []
        if entity.components[ModelComponent.self] != nil {
            entities.append(entity)
        }
        for child in entity.children {
            entities.append(contentsOf: modelEntities(in: child))
        }
        return entities
    }
}

private extension MaterialConfig.Params {
    var clockTextureRect: SIMD4<Float> {
        guard let clockUVRect, clockUVRect.count == 4 else {
            return [0.26, 0.035, 0.5, 0.095]
        }
        return [clockUVRect[0], clockUVRect[1], clockUVRect[2], clockUVRect[3]]
    }

    var clockTintColor: SIMD3<Float> {
        guard let clockTint, clockTint.count == 3 else {
            return [0.95, 0.22, 0.12]
        }
        return [clockTint[0], clockTint[1], clockTint[2]]
    }
}

private struct ClockDisplayFrame {
    let hour: Int
    let minute: Int
    let colonVisible: Bool

    init(date: Date) {
        let calendar = Calendar.autoupdatingCurrent
        hour = calendar.component(.hour, from: date)
        minute = calendar.component(.minute, from: date)
        colonVisible = calendar.component(.second, from: date).isMultiple(of: 2)
    }

    var key: String {
        String(format: "%02d:%02d:%d", hour, minute, colonVisible ? 1 : 0)
    }

    var digits: [Int] {
        [hour / 10, hour % 10, minute / 10, minute % 10]
    }
}

private enum ClockTextureRenderer {
    private static let textureSize = CGSize(width: 1024, height: 1024)

    static func render(
        frame: ClockDisplayFrame,
        uvRect: SIMD4<Float>,
        flipU: Bool,
        flipV: Bool,
        tint: SIMD3<Float>
    ) throws -> CGImage {
        let width = Int(textureSize.width)
        let height = Int(textureSize.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw ClockTextureError.contextUnavailable
        }

        context.clear(CGRect(origin: .zero, size: textureSize))

        let rect = pixelRect(from: uvRect)
        if flipU || flipV {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.scaleBy(x: flipU ? -1 : 1, y: flipV ? -1 : 1)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }
        drawClock(frame: frame, in: rect, tint: tint, context: context)

        guard let image = context.makeImage() else {
            throw ClockTextureError.imageUnavailable
        }
        return image
    }

    private static func pixelRect(from uvRect: SIMD4<Float>) -> CGRect {
        CGRect(
            x: CGFloat(uvRect.x) * textureSize.width,
            y: CGFloat(uvRect.y) * textureSize.height,
            width: CGFloat(uvRect.z) * textureSize.width,
            height: CGFloat(uvRect.w) * textureSize.height
        )
    }

    private static func drawClock(
        frame: ClockDisplayFrame,
        in rect: CGRect,
        tint: SIMD3<Float>,
        context: CGContext
    ) {
        let padded = rect.insetBy(dx: rect.width * 0.055, dy: rect.height * 0.12)
        let colonRatio: CGFloat = 0.24
        let digitGapRatio: CGFloat = 0.09
        let colonGapRatio: CGFloat = 0.22
        let digitAspect: CGFloat = 0.56

        let widthDrivenDigitWidth = padded.width / (4 + colonRatio + digitGapRatio * 2 + colonGapRatio * 2)
        let heightDrivenDigitWidth = padded.height * digitAspect
        let digitWidth = min(widthDrivenDigitWidth, heightDrivenDigitWidth)
        let digitHeight = digitWidth / digitAspect
        let digitGap = digitWidth * digitGapRatio
        let colonGap = digitWidth * colonGapRatio
        let colonWidth = digitWidth * colonRatio
        let totalWidth = digitWidth * 4 + colonWidth + digitGap * 2 + colonGap * 2

        var x = padded.midX - totalWidth / 2
        let y = padded.midY - digitHeight / 2
        let digitSize = CGSize(width: digitWidth, height: digitHeight)
        let color = CGColor(red: CGFloat(tint.x), green: CGFloat(tint.y), blue: CGFloat(tint.z), alpha: 1)

        drawDigit(frame.digits[0], in: CGRect(origin: CGPoint(x: x, y: y), size: digitSize), color: color, context: context)
        x += digitWidth + digitGap
        drawDigit(frame.digits[1], in: CGRect(origin: CGPoint(x: x, y: y), size: digitSize), color: color, context: context)
        x += digitWidth + colonGap
        drawColon(
            visible: frame.colonVisible,
            in: CGRect(x: x, y: y, width: colonWidth, height: digitHeight),
            color: color,
            context: context
        )
        x += colonWidth + colonGap
        drawDigit(frame.digits[2], in: CGRect(origin: CGPoint(x: x, y: y), size: digitSize), color: color, context: context)
        x += digitWidth + digitGap
        drawDigit(frame.digits[3], in: CGRect(origin: CGPoint(x: x, y: y), size: digitSize), color: color, context: context)
    }

    private static func drawDigit(_ value: Int, in rect: CGRect, color: CGColor, context: CGContext) {
        let activeSegments = segments(for: value)
        let baseThickness = min(rect.width, rect.height) * 0.115
        let passes: [(scale: CGFloat, alpha: CGFloat)] = [
            (4.5, 0.06),
            (2.5, 0.13),
            (1.0, 0.95)
        ]

        for pass in passes {
            let thickness = baseThickness * pass.scale
            context.setFillColor(color.copy(alpha: pass.alpha) ?? color)
            for segment in activeSegments {
                context.fill(segmentRect(segment, in: rect, thickness: thickness))
            }
        }
    }

    private static func drawColon(visible: Bool, in rect: CGRect, color: CGColor, context: CGContext) {
        guard visible else { return }

        let dotSize = min(rect.width, rect.height) * 0.24
        let centers = [
            CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.19),
            CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.19)
        ]
        let passes: [(scale: CGFloat, alpha: CGFloat)] = [
            (4.0, 0.06),
            (2.25, 0.13),
            (1.0, 0.95)
        ]

        for pass in passes {
            context.setFillColor(color.copy(alpha: pass.alpha) ?? color)
            for center in centers {
                let size = dotSize * pass.scale
                context.fillEllipse(in: CGRect(
                    x: center.x - size / 2,
                    y: center.y - size / 2,
                    width: size,
                    height: size
                ))
            }
        }
    }

    private static func segmentRect(_ segment: SevenSegment, in rect: CGRect, thickness: CGFloat) -> CGRect {
        let inset = thickness * 0.62
        let horizontalWidth = max(rect.width - inset * 2, thickness)
        let verticalHeight = max((rect.height - thickness * 3) / 2, thickness)

        switch segment {
        case .top:
            return CGRect(x: rect.minX + inset, y: rect.maxY - thickness, width: horizontalWidth, height: thickness)
        case .middle:
            return CGRect(x: rect.minX + inset, y: rect.midY - thickness / 2, width: horizontalWidth, height: thickness)
        case .bottom:
            return CGRect(x: rect.minX + inset, y: rect.minY, width: horizontalWidth, height: thickness)
        case .upperLeft:
            return CGRect(x: rect.minX, y: rect.midY + thickness / 2, width: thickness, height: verticalHeight)
        case .upperRight:
            return CGRect(x: rect.maxX - thickness, y: rect.midY + thickness / 2, width: thickness, height: verticalHeight)
        case .lowerLeft:
            return CGRect(x: rect.minX, y: rect.minY + thickness, width: thickness, height: verticalHeight)
        case .lowerRight:
            return CGRect(x: rect.maxX - thickness, y: rect.minY + thickness, width: thickness, height: verticalHeight)
        }
    }

    private static func segments(for digit: Int) -> [SevenSegment] {
        switch digit {
        case 0: [.top, .upperLeft, .upperRight, .lowerLeft, .lowerRight, .bottom]
        case 1: [.upperRight, .lowerRight]
        case 2: [.top, .upperRight, .middle, .lowerLeft, .bottom]
        case 3: [.top, .upperRight, .middle, .lowerRight, .bottom]
        case 4: [.upperLeft, .upperRight, .middle, .lowerRight]
        case 5: [.top, .upperLeft, .middle, .lowerRight, .bottom]
        case 6: [.top, .upperLeft, .middle, .lowerLeft, .lowerRight, .bottom]
        case 7: [.top, .upperRight, .lowerRight]
        case 8: [.top, .upperLeft, .upperRight, .middle, .lowerLeft, .lowerRight, .bottom]
        case 9: [.top, .upperLeft, .upperRight, .middle, .lowerRight, .bottom]
        default: []
        }
    }
}

private enum SevenSegment {
    case top
    case upperLeft
    case upperRight
    case middle
    case lowerLeft
    case lowerRight
    case bottom
}

private enum ClockTextureError: Error {
    case contextUnavailable
    case imageUnavailable
}
