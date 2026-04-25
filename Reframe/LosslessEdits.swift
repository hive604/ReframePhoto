//
//  LosslessEdits.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

public struct LosslessEdits: Codable, Hashable {
    /// Image center is 0.0.
    /// Thanks to rotation, this can extend past (-0.5...0.5).
    public var crop: CGRect?

    /// Rotation of image.
    public var rotation: Angle

    public var brightness: Double
    public var contrast: Double
    public var saturation: Double

    public init(
        crop: CGRect? = nil,
        rotation: Angle,
        brightness: Double = 0.0,
        contrast: Double = 1.0,
        saturation: Double = 1.0
    ) {
        self.crop = crop
        self.rotation = rotation
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
    }

    enum CodingKeys: String, CodingKey {
        case crop
        case rotation
        case brightness
        case contrast
        case saturation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        crop = try container.decodeIfPresent(CGRect.self, forKey: .crop)
        rotation = try container.decode(Angle.self, forKey: .rotation)
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(crop, forKey: .crop)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(saturation, forKey: .saturation)
    }
}

public extension UIImage {
    func applying(_ edits: LosslessEdits) -> UIImage? {
        applying(edits, outputSize: size)
    }

    func applying(_ edits: LosslessEdits, outputSize: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }

        let sourceImage = applyingColorAdjustments(using: edits, targetSize: outputSize) ?? self
        let imageSize = sourceImage.size
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: imageSize, in: imageSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: edits.rotation)

        let cropFrame: CGRect
        if let crop = edits.crop?.standardized,
           crop.width > 0.0001,
           crop.height > 0.0001 {
            cropFrame = LosslessEditGeometry.croppedFrame(
                from: crop,
                in: imageSize,
                visibleImageSize: visibleImageSize
            )
        } else {
            cropFrame = LosslessEditGeometry.uncroppedFrame(
                in: imageSize,
                visibleImageSize: visibleImageSize,
                rotation: edits.rotation
            )
        }

        let outputScale = min(
            outputSize.width / cropFrame.width,
            outputSize.height / cropFrame.height,
            1
        )
        let outputBounds = CGRect(origin: .zero, size: CGSize(
            width: ceil(cropFrame.width * outputScale),
            height: ceil(cropFrame.height * outputScale)
        ))
        guard outputBounds.width > 0, outputBounds.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: outputBounds.size, format: format)

        return renderer.image { _ in
            let outputCenter = CGPoint(x: outputBounds.midX, y: outputBounds.midY)

            let context = UIGraphicsGetCurrentContext()
            context?.translateBy(x: outputCenter.x, y: outputCenter.y)
            context?.rotate(by: CGFloat(edits.rotation.radians))
            context?.scaleBy(
                x: (visibleImageSize.width / imageSize.width) * outputScale,
                y: (visibleImageSize.height / imageSize.height) * outputScale
            )

            let imageRect = CGRect(
                x: -imageSize.width / 2 - (cropFrame.midX - imageSize.width / 2),
                y: -imageSize.height / 2 - (cropFrame.midY - imageSize.height / 2),
                width: imageSize.width,
                height: imageSize.height
            )

            sourceImage.draw(in: imageRect)
        }
    }
}

extension UIImage {
    func applyingColorAdjustments(using edits: LosslessEdits, targetSize: CGSize? = nil) -> UIImage? {
        let workingImage = resizedToFit(targetSize) ?? self
        guard let inputImage = CIImage(image: workingImage) else { return nil }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = inputImage
        colorControls.brightness = Float(edits.brightness)
        colorControls.contrast = Float(edits.contrast)
        colorControls.saturation = Float(edits.saturation)

        guard let outputImage = colorControls.outputImage else { return nil }
        let context = CIContext(options: nil)

        guard let renderedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: renderedCGImage, scale: workingImage.scale, orientation: .up)
    }

    private func resizedToFit(_ targetSize: CGSize?) -> UIImage? {
        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else { return nil }
        guard size.width > targetSize.width || size.height > targetSize.height else { return self }

        let fittedSize = LosslessEditGeometry.aspectFitSize(for: size, in: targetSize)
        guard fittedSize.width > 0, fittedSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: fittedSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: fittedSize))
        }
    }
}
