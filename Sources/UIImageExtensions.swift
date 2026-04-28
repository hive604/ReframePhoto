//
//  UIImageExtensions.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

public extension UIImage {
    /// Applies the provided lossless edits using the image's current size as the render target.
    ///
    /// This applies crop, rotation, and color adjustments. The `cropConstraint` stored in
    /// `LosslessEdits` is preserved for UI state only and is not used during rendering.
    func applying(_ edits: LosslessEdits) -> UIImage? {
        applying(edits, outputSize: size)
    }

    /// Applies the provided lossless edits and renders the result to fit the requested output size.
    ///
    /// This applies crop, rotation, and color adjustments. The `cropConstraint` stored in
    /// `LosslessEdits` is preserved for UI state only and is not used during rendering.
    ///
    /// - Parameters:
    ///   - edits: The edit description to render.
    ///   - outputSize: The maximum rendered image size.
    /// - Returns: A new image containing the rendered edits, or `nil` if rendering fails.
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

        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = inputImage
        temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
        temperatureAndTint.targetNeutral = CIVector(
            x: 6500 - (CGFloat(edits.warmth) * 2000),
            y: CGFloat(edits.tint) * 100
        )

        guard let whiteBalancedImage = temperatureAndTint.outputImage else { return nil }

        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = whiteBalancedImage
        vibrance.amount = Float(edits.vibrance)

        guard let vibranceAdjustedImage = vibrance.outputImage else { return nil }

        let exposureAdjust = CIFilter.exposureAdjust()
        exposureAdjust.inputImage = vibranceAdjustedImage
        exposureAdjust.ev = Float(edits.exposure)

        guard let exposureAdjustedImage = exposureAdjust.outputImage else { return nil }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = exposureAdjustedImage
        colorControls.brightness = Float(edits.brightness)
        colorControls.contrast = Float(edits.contrast)
        colorControls.saturation = Float(edits.saturation)

        guard let colorAdjustedImage = colorControls.outputImage else { return nil }

        let sharpenLuminance = CIFilter.sharpenLuminance()
        sharpenLuminance.inputImage = colorAdjustedImage
        sharpenLuminance.sharpness = Float(edits.sharpness)

        guard let outputImage = sharpenLuminance.outputImage else { return nil }
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
