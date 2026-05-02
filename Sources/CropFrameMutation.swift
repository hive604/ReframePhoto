//
//  CropFrameMutation.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-05-02.
//

import SwiftUI

enum CropFrameMutation {
    enum MovingEdges {
        case all
        case corner(CropCornerHandle)
        case edge(CropEdgeHandle)

        var affectedEdges: [CropEdgeHandle] {
            switch self {
            case .all:
                [.top, .bottom, .left, .right]
            case let .corner(handle):
                switch handle {
                case .topLeft:
                    [.top, .left]
                case .topRight:
                    [.top, .right]
                case .bottomLeft:
                    [.bottom, .left]
                case .bottomRight:
                    [.bottom, .right]
                }
            case let .edge(handle):
                [handle]
            }
        }
    }

    static func translatedCropFrame(_ cropFrame: CGRect, by translation: CGSize) -> CGRect {
        cropFrame.offsetBy(dx: translation.width, dy: translation.height)
    }

    static func aspectRatioAdjustedCropFrame(_ cropFrame: CGRect, ratio: CGFloat) -> CGRect {
        guard cropFrame.width > 0, cropFrame.height > 0, ratio > 0 else { return cropFrame }

        let currentRatio = cropFrame.width / cropFrame.height
        let center = CGPoint(x: cropFrame.midX, y: cropFrame.midY)

        let size: CGSize
        if currentRatio > ratio {
            size = CGSize(width: cropFrame.height * ratio, height: cropFrame.height)
        } else {
            size = CGSize(width: cropFrame.width, height: cropFrame.width / ratio)
        }

        return CGRect(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    static func resizedCropFrame(
        _ cropFrame: CGRect,
        byResizing handle: CropCornerHandle,
        translation: CGSize,
        minimumNormalizedCropSize: CGFloat,
        visibleImageSize: CGSize,
        cropConstraint: CropConstraint
    ) -> CGRect {
        guard let ratio = cropConstraint.ratio else {
            return resizedCropFrameFreeform(
                cropFrame,
                byResizing: handle,
                translation: translation,
                minimumNormalizedCropSize: minimumNormalizedCropSize,
                visibleImageSize: visibleImageSize
            )
        }

        let minimumSize = minimumAspectLockedSize(
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize,
            ratio: ratio
        )
        let scaleX = proposedWidth(for: handle, cropFrame: cropFrame, translation: translation) / max(cropFrame.width, 0.0001)
        let scaleY = proposedHeight(for: handle, cropFrame: cropFrame, translation: translation) / max(cropFrame.height, 0.0001)
        let scale = abs(scaleX - 1) > abs(scaleY - 1) ? scaleX : scaleY

        let width = max(minimumSize.width, cropFrame.width * scale)
        let height = max(minimumSize.height, width / ratio)

        switch handle {
        case .topLeft:
            return CGRect(
                x: cropFrame.maxX - width,
                y: cropFrame.maxY - height,
                width: width,
                height: height
            )
        case .topRight:
            return CGRect(
                x: cropFrame.minX,
                y: cropFrame.maxY - height,
                width: width,
                height: height
            )
        case .bottomLeft:
            return CGRect(
                x: cropFrame.maxX - width,
                y: cropFrame.minY,
                width: width,
                height: height
            )
        case .bottomRight:
            return CGRect(
                x: cropFrame.minX,
                y: cropFrame.minY,
                width: width,
                height: height
            )
        }
    }

    static func resizedCropFrame(
        _ cropFrame: CGRect,
        byResizing handle: CropEdgeHandle,
        translation: CGSize,
        minimumNormalizedCropSize: CGFloat,
        visibleImageSize: CGSize,
        cropConstraint: CropConstraint
    ) -> CGRect {
        guard let ratio = cropConstraint.ratio else {
            return resizedCropFrameFreeform(
                cropFrame,
                byResizing: handle,
                translation: translation,
                minimumNormalizedCropSize: minimumNormalizedCropSize,
                visibleImageSize: visibleImageSize
            )
        }

        let minimumSize = minimumAspectLockedSize(
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize,
            ratio: ratio
        )
        let midX = cropFrame.midX
        let midY = cropFrame.midY

        switch handle {
        case .left:
            let width = max(minimumSize.width, cropFrame.width - translation.width)
            let height = max(minimumSize.height, width / ratio)
            return CGRect(
                x: cropFrame.maxX - width,
                y: midY - (height / 2),
                width: width,
                height: height
            )
        case .right:
            let width = max(minimumSize.width, cropFrame.width + translation.width)
            let height = max(minimumSize.height, width / ratio)
            return CGRect(
                x: cropFrame.minX,
                y: midY - (height / 2),
                width: width,
                height: height
            )
        case .top:
            let height = max(minimumSize.height, cropFrame.height - translation.height)
            let width = max(minimumSize.width, height * ratio)
            return CGRect(
                x: midX - (width / 2),
                y: cropFrame.maxY - height,
                width: width,
                height: height
            )
        case .bottom:
            let height = max(minimumSize.height, cropFrame.height + translation.height)
            let width = max(minimumSize.width, height * ratio)
            return CGRect(
                x: midX - (width / 2),
                y: cropFrame.minY,
                width: width,
                height: height
            )
        }
    }

    private static func resizedCropFrameFreeform(
        _ cropFrame: CGRect,
        byResizing handle: CropCornerHandle,
        translation: CGSize,
        minimumNormalizedCropSize: CGFloat,
        visibleImageSize: CGSize
    ) -> CGRect {
        var updated = cropFrame
        let minimumWidth = visibleImageSize.width * minimumNormalizedCropSize
        let minimumHeight = visibleImageSize.height * minimumNormalizedCropSize

        switch handle {
        case .topLeft:
            updated.origin.x += translation.width
            updated.origin.y += translation.height
            updated.size.width -= translation.width
            updated.size.height -= translation.height
        case .topRight:
            updated.origin.y += translation.height
            updated.size.width += translation.width
            updated.size.height -= translation.height
        case .bottomLeft:
            updated.origin.x += translation.width
            updated.size.width -= translation.width
            updated.size.height += translation.height
        case .bottomRight:
            updated.size.width += translation.width
            updated.size.height += translation.height
        }

        if updated.width < minimumWidth {
            switch handle {
            case .topLeft, .bottomLeft:
                updated.origin.x = cropFrame.maxX - minimumWidth
            case .topRight, .bottomRight:
                break
            }
            updated.size.width = minimumWidth
        }

        if updated.height < minimumHeight {
            switch handle {
            case .topLeft, .topRight:
                updated.origin.y = cropFrame.maxY - minimumHeight
            case .bottomLeft, .bottomRight:
                break
            }
            updated.size.height = minimumHeight
        }

        return updated
    }

    private static func resizedCropFrameFreeform(
        _ cropFrame: CGRect,
        byResizing handle: CropEdgeHandle,
        translation: CGSize,
        minimumNormalizedCropSize: CGFloat,
        visibleImageSize: CGSize
    ) -> CGRect {
        var updated = cropFrame
        let minimumWidth = visibleImageSize.width * minimumNormalizedCropSize
        let minimumHeight = visibleImageSize.height * minimumNormalizedCropSize

        switch handle {
        case .left:
            updated.origin.x += translation.width
            updated.size.width -= translation.width
        case .right:
            updated.size.width += translation.width
        case .top:
            updated.origin.y += translation.height
            updated.size.height -= translation.height
        case .bottom:
            updated.size.height += translation.height
        }

        if updated.width < minimumWidth {
            switch handle {
            case .left:
                updated.origin.x = cropFrame.maxX - minimumWidth
            case .right, .top, .bottom:
                break
            }
            updated.size.width = minimumWidth
        }

        if updated.height < minimumHeight {
            switch handle {
            case .top:
                updated.origin.y = cropFrame.maxY - minimumHeight
            case .bottom, .left, .right:
                break
            }
            updated.size.height = minimumHeight
        }

        return updated
    }

    private static func proposedWidth(for handle: CropCornerHandle, cropFrame: CGRect, translation: CGSize) -> CGFloat {
        switch handle {
        case .topLeft, .bottomLeft:
            cropFrame.width - translation.width
        case .topRight, .bottomRight:
            cropFrame.width + translation.width
        }
    }

    private static func proposedHeight(for handle: CropCornerHandle, cropFrame: CGRect, translation: CGSize) -> CGFloat {
        switch handle {
        case .topLeft, .topRight:
            cropFrame.height - translation.height
        case .bottomLeft, .bottomRight:
            cropFrame.height + translation.height
        }
    }

    private static func minimumAspectLockedSize(
        minimumNormalizedCropSize: CGFloat,
        visibleImageSize: CGSize,
        ratio: CGFloat
    ) -> CGSize {
        let minimumWidth = visibleImageSize.width * minimumNormalizedCropSize
        let minimumHeight = visibleImageSize.height * minimumNormalizedCropSize
        let lockedMinimumWidth = max(minimumWidth, minimumHeight * ratio)

        return CGSize(
            width: lockedMinimumWidth,
            height: lockedMinimumWidth / ratio
        )
    }

    static func clamped(cropFrame: CGRect, to bounds: CGRect) -> CGRect {
        var clamped = cropFrame

        if clamped.minX < bounds.minX {
            clamped.origin.x = bounds.minX
        }
        if clamped.minY < bounds.minY {
            clamped.origin.y = bounds.minY
        }
        if clamped.maxX > bounds.maxX {
            clamped.origin.x = bounds.maxX - clamped.width
        }
        if clamped.maxY > bounds.maxY {
            clamped.origin.y = bounds.maxY - clamped.height
        }

        return clamped
    }

    static func constrainedCropFrame(
        _ cropFrame: CGRect,
        moving: MovingEdges,
        within bounds: CGRect,
        visibleImageSize: CGSize,
        rotation: Angle,
        cropConstraint: CropConstraint
    ) -> CGRect {
        let cropBounds = CropBounds(
            in: bounds,
            visibleImageSize: visibleImageSize,
            rotation: rotation
        )
        let standardizedCropFrame = cropFrame.standardized

        switch moving {
        case .all:
            return clamped(cropFrame: standardizedCropFrame, to: cropBounds.maximumFrame)
        case .corner, .edge:
            if let ratio = cropConstraint.ratio {
                return clampAspectLockedCropFrame(
                    standardizedCropFrame,
                    moving: moving,
                    within: cropBounds,
                    ratio: ratio
                )
            }

            return clampFreeformCropFrame(
                standardizedCropFrame,
                moving: moving,
                within: cropBounds
            )
        }
    }

    private static func clampFreeformCropFrame(
        _ cropFrame: CGRect,
        moving: MovingEdges,
        within bounds: CropBounds
    ) -> CGRect {
        var constrained = cropFrame

        for edge in moving.affectedEdges {
            switch edge {
            case .top:
                constrained = clampTopEdge(of: constrained, within: bounds)
            case .bottom:
                constrained = clampBottomEdge(of: constrained, within: bounds)
            case .left:
                constrained = clampLeftEdge(of: constrained, within: bounds)
            case .right:
                constrained = clampRightEdge(of: constrained, within: bounds)
            }
        }

        return constrained
    }

    private static func clampAspectLockedCropFrame(
        _ cropFrame: CGRect,
        moving: MovingEdges,
        within bounds: CropBounds,
        ratio: CGFloat
    ) -> CGRect {
        switch moving {
        case let .corner(handle):
            clampAspectLockedCornerCropFrame(cropFrame, handle: handle, within: bounds, ratio: ratio)
        case let .edge(handle):
            clampAspectLockedEdgeCropFrame(cropFrame, handle: handle, within: bounds, ratio: ratio)
        case .all:
            clamped(cropFrame: cropFrame, to: bounds.maximumFrame)
        }
    }

    private static func clampAspectLockedCornerCropFrame(
        _ cropFrame: CGRect,
        handle: CropCornerHandle,
        within bounds: CropBounds,
        ratio: CGFloat
    ) -> CGRect {
        let maximumFrame = bounds.maximumFrame
        let proposedWidth = cropFrame.width

        let anchor: CGPoint
        let maximumWidth: CGFloat
        switch handle {
        case .topLeft:
            anchor = CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
            maximumWidth = min(proposedWidth, anchor.x - maximumFrame.minX, (anchor.y - maximumFrame.minY) * ratio)
        case .topRight:
            anchor = CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
            maximumWidth = min(proposedWidth, maximumFrame.maxX - anchor.x, (anchor.y - maximumFrame.minY) * ratio)
        case .bottomLeft:
            anchor = CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
            maximumWidth = min(proposedWidth, anchor.x - maximumFrame.minX, (maximumFrame.maxY - anchor.y) * ratio)
        case .bottomRight:
            anchor = CGPoint(x: cropFrame.minX, y: cropFrame.minY)
            maximumWidth = min(proposedWidth, maximumFrame.maxX - anchor.x, (maximumFrame.maxY - anchor.y) * ratio)
        }

        return rectFromCorner(anchor: anchor, handle: handle, width: max(1, maximumWidth), ratio: ratio)
    }

    private static func rectFromCorner(
        anchor: CGPoint,
        handle: CropCornerHandle,
        width: CGFloat,
        ratio: CGFloat
    ) -> CGRect {
        let height = width / ratio

        switch handle {
        case .topLeft:
            return CGRect(x: anchor.x - width, y: anchor.y - height, width: width, height: height)
        case .topRight:
            return CGRect(x: anchor.x, y: anchor.y - height, width: width, height: height)
        case .bottomLeft:
            return CGRect(x: anchor.x - width, y: anchor.y, width: width, height: height)
        case .bottomRight:
            return CGRect(x: anchor.x, y: anchor.y, width: width, height: height)
        }
    }

    private static func clampAspectLockedEdgeCropFrame(
        _ cropFrame: CGRect,
        handle: CropEdgeHandle,
        within bounds: CropBounds,
        ratio: CGFloat
    ) -> CGRect {
        let maximumFrame = bounds.maximumFrame
        let center = CGPoint(x: cropFrame.midX, y: cropFrame.midY)

        switch handle {
        case .top:
            let maximumHeight = min(
                cropFrame.height,
                cropFrame.maxY - maximumFrame.minY,
                horizontalCenteredLimit(from: center.x, within: maximumFrame) / ratio
            )
            let height = max(1, maximumHeight)
            let width = height * ratio
            return CGRect(x: center.x - width / 2, y: cropFrame.maxY - height, width: width, height: height)
        case .bottom:
            let maximumHeight = min(
                cropFrame.height,
                maximumFrame.maxY - cropFrame.minY,
                horizontalCenteredLimit(from: center.x, within: maximumFrame) / ratio
            )
            let height = max(1, maximumHeight)
            let width = height * ratio
            return CGRect(x: center.x - width / 2, y: cropFrame.minY, width: width, height: height)
        case .left:
            let maximumWidth = min(
                cropFrame.width,
                cropFrame.maxX - maximumFrame.minX,
                verticalCenteredLimit(from: center.y, within: maximumFrame) * ratio
            )
            let width = max(1, maximumWidth)
            let height = width / ratio
            return CGRect(x: cropFrame.maxX - width, y: center.y - height / 2, width: width, height: height)
        case .right:
            let maximumWidth = min(
                cropFrame.width,
                maximumFrame.maxX - cropFrame.minX,
                verticalCenteredLimit(from: center.y, within: maximumFrame) * ratio
            )
            let width = max(1, maximumWidth)
            let height = width / ratio
            return CGRect(x: cropFrame.minX, y: center.y - height / 2, width: width, height: height)
        }
    }

    private static func horizontalCenteredLimit(from x: CGFloat, within bounds: CGRect) -> CGFloat {
        2 * min(x - bounds.minX, bounds.maxX - x)
    }

    private static func verticalCenteredLimit(from y: CGFloat, within bounds: CGRect) -> CGFloat {
        2 * min(y - bounds.minY, bounds.maxY - y)
    }

    private static func clampTopEdge(of cropFrame: CGRect, within bounds: CropBounds) -> CGRect {
        let maxY = cropFrame.maxY
        let minY = max(cropFrame.minY, bounds.maximumFrame.minY)
        return CGRect(x: cropFrame.minX, y: minY, width: cropFrame.width, height: maxY - minY)
    }

    private static func clampBottomEdge(of cropFrame: CGRect, within bounds: CropBounds) -> CGRect {
        let maxY = min(cropFrame.maxY, bounds.maximumFrame.maxY)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: cropFrame.width, height: maxY - cropFrame.minY)
    }

    private static func clampLeftEdge(of cropFrame: CGRect, within bounds: CropBounds) -> CGRect {
        let maxX = cropFrame.maxX
        let minX = max(cropFrame.minX, bounds.maximumFrame.minX)
        return CGRect(x: minX, y: cropFrame.minY, width: maxX - minX, height: cropFrame.height)
    }

    private static func clampRightEdge(of cropFrame: CGRect, within bounds: CropBounds) -> CGRect {
        let maxX = min(cropFrame.maxX, bounds.maximumFrame.maxX)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: maxX - cropFrame.minX, height: cropFrame.height)
    }
}
