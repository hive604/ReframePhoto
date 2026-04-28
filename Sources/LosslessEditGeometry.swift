//
//  LosslessEditGeometry.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-23.
//

import SwiftUI

/// Converts between stored crop coordinates and editor display-space frames.
/// Stored crop coordinates are normalized around the visible image center, so tilted crops may extend below 0 or above 1.
enum LosslessEditGeometry {
    static func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return .zero
        }

        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let scale = min(widthScale, heightScale)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    static func visibleImageSize(for fittedSize: CGSize, angle: Angle) -> CGSize {
        let fitScale = rotationFitScale(for: fittedSize, angle: angle)

        return CGSize(
            width: fittedSize.width * fitScale,
            height: fittedSize.height * fitScale
        )
    }

    static func rotationFitScale(for size: CGSize, angle: Angle) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        let rotatedSize = rotatedBoundingSize(for: size, angle: angle)
        guard rotatedSize.width > 0, rotatedSize.height > 0 else { return 1 }

        let horizontalScale = size.width / rotatedSize.width
        let verticalScale = size.height / rotatedSize.height

        return min(horizontalScale, verticalScale, 1)
    }

    static func rotatedBoundingSize(for size: CGSize, angle: Angle) -> CGSize {
        let radians = angle.radians
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))

        return CGSize(
            width: size.width * absoluteCosine + size.height * absoluteSine,
            height: size.width * absoluteSine + size.height * absoluteCosine
        )
    }

    static func uncroppedFrame(in geometrySize: CGSize, visibleImageSize: CGSize, rotation: Angle) -> CGRect {
        let rotatedSize = rotatedBoundingSize(for: visibleImageSize, angle: rotation)

        return CGRect(
            x: (geometrySize.width - rotatedSize.width) / 2,
            y: (geometrySize.height - rotatedSize.height) / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )
    }

    static func croppedFrame(from crop: CGRect, in geometrySize: CGSize, visibleImageSize: CGSize) -> CGRect {
        let center = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)

        let minX = center.x + (crop.minX * visibleImageSize.width)
        let maxX = center.x + (crop.maxX * visibleImageSize.width)
        let minY = center.y + (crop.minY * visibleImageSize.height)
        let maxY = center.y + (crop.maxY * visibleImageSize.height)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func normalizedCrop(from cropFrame: CGRect, in geometrySize: CGSize, visibleImageSize: CGSize) -> CGRect? {
        guard visibleImageSize.width > 0, visibleImageSize.height > 0 else { return nil }
        let center = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)

        return CGRect(
            x: (cropFrame.minX - center.x) / visibleImageSize.width,
            y: (cropFrame.minY - center.y) / visibleImageSize.height,
            width: cropFrame.width / visibleImageSize.width,
            height: cropFrame.height / visibleImageSize.height
        )
    }
}
