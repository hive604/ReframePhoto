//
//  CroppingView.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-22.
//

import SwiftUI

struct CroppingView: View {
    private let minimumNormalizedCropSize: CGFloat = 0.15
    private let minimumStoredCropDimension: CGFloat = 0.0001
    private let cropHandleSize: CGFloat = 28

    let image: UIImage
    let canvasSize: CGSize
    @Binding var edits: LosslessEdits
    let photoEditConfiguration: PhotoEditConfiguration

    @State private var draftCropFrame: CGRect?
    @State private var cropGestureStartFrame: CGRect?
    @State private var isShowingAspectRatioPopover = false

    init(image: UIImage, canvasSize: CGSize, edits: Binding<LosslessEdits>, photoEditConfiguration: PhotoEditConfiguration) {
        self.image = image
        self.canvasSize = canvasSize
        _edits = edits
        self.photoEditConfiguration = photoEditConfiguration
    }

    var body: some View {
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: image.size, in: canvasSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: edits.rotation)
        let currentCropFrame = effectiveCropFrame(visibleImageSize: visibleImageSize)

        VStack(spacing: 0) {
            ZStack {
                baseImage(fittedSize: fittedSize)

                if blurRadius > 0 || desaturateAmount > 0 {
                    outsideCropEffectImage(fittedSize: fittedSize)
                        .mask(
                            CropDimmedAreaShape(
                                outerRect: cropWorkspaceRect,
                                cropRect: currentCropFrame
                            )
                            .fill(style: FillStyle(eoFill: true, antialiased: false))
                        )
                }

                CropDimmedAreaShape(
                    outerRect: cropWorkspaceRect,
                    cropRect: currentCropFrame
                )
                .fill(.black.opacity(dimOpacity), style: FillStyle(eoFill: true))

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .overlay {
                        Rectangle()
                            .stroke(.white, lineWidth: 2)
                    }
                    .frame(width: currentCropFrame.width, height: currentCropFrame.height)
                    .position(x: currentCropFrame.midX, y: currentCropFrame.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                beginCropGesture(from: currentCropFrame)
                                updateCropFrame(
                                    byTranslatingFrom: cropGestureStartFrame ?? currentCropFrame,
                                    translation: value.translation,
                                    visibleImageSize: visibleImageSize
                                )
                            }
                            .onEnded { _ in
                                cropGestureStartFrame = nil
                            }
                    )

                cropEdgeHandle(.top, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropEdgeHandle(.bottom, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropEdgeHandle(.left, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropEdgeHandle(.right, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)

                cropCornerHandle(.topLeft, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropCornerHandle(.topRight, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropCornerHandle(.bottomLeft, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
                cropCornerHandle(.bottomRight, cropFrame: currentCropFrame, visibleImageSize: visibleImageSize)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
        .onChange(of: edits.cropConstraint) { _, _ in
            // External aspect-ratio changes should defer to the committed crop state.
            draftCropFrame = nil
            cropGestureStartFrame = nil
        }
    }

    private var cropWorkspaceRect: CGRect {
        CGRect(origin: .zero, size: canvasSize)
    }

    private func aspectRatioPopover(currentCropFrame: CGRect, visibleImageSize: CGSize) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(CropConstraint.displayOrder, id: \.self) { constraint in
                Button {
                    edits.cropConstraint = constraint
                    updateCropFrame(
                        for: constraint,
                        from: currentCropFrame,
                        visibleImageSize: visibleImageSize
                    )
                    isShowingAspectRatioPopover = false
                } label: {
                    HStack {
                        Text(constraint.label)
                            .font(.callout.weight(.medium))
                        Spacer(minLength: 8)
                        if edits.cropConstraint == constraint {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 240)
    }

    private func cropCornerHandle(
        _ handle: CropCornerHandle,
        cropFrame: CGRect,
        visibleImageSize: CGSize
    ) -> some View {
        Circle()
            .fill(.white)
            .frame(width: cropHandleSize, height: cropHandleSize)
            .overlay {
                Circle().stroke(.black.opacity(0.35), lineWidth: 1)
            }
            .position(position(for: handle, in: cropFrame))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        beginCropGesture(from: cropFrame)
                        updateCropFrame(
                            byResizing: handle,
                            from: cropGestureStartFrame ?? cropFrame,
                            translation: value.translation,
                            visibleImageSize: visibleImageSize
                        )
                    }
                    .onEnded { _ in
                        cropGestureStartFrame = nil
                    }
            )
    }

    private func position(for handle: CropCornerHandle, in cropFrame: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .topRight:
            CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .bottomLeft:
            CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .bottomRight:
            CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        }
    }

    private func cropEdgeHandle(
        _ handle: CropEdgeHandle,
        cropFrame: CGRect,
        visibleImageSize: CGSize
    ) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .frame(
                width: edgeHandleSize(for: handle).width,
                height: edgeHandleSize(for: handle).height
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(.black.opacity(0.35), lineWidth: 1)
            }
            .position(position(for: handle, in: cropFrame))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        beginCropGesture(from: cropFrame)
                        updateCropFrame(
                            byResizing: handle,
                            from: cropGestureStartFrame ?? cropFrame,
                            translation: value.translation,
                            visibleImageSize: visibleImageSize
                        )
                    }
                    .onEnded { _ in
                        cropGestureStartFrame = nil
                    }
            )
    }

    private func edgeHandleSize(for handle: CropEdgeHandle) -> CGSize {
        switch handle {
        case .top, .bottom:
            CGSize(width: cropHandleSize * 1.6, height: cropHandleSize * 0.6)
        case .left, .right:
            CGSize(width: cropHandleSize * 0.6, height: cropHandleSize * 1.6)
        }
    }

    private func position(for handle: CropEdgeHandle, in cropFrame: CGRect) -> CGPoint {
        switch handle {
        case .top:
            CGPoint(x: cropFrame.midX, y: cropFrame.minY)
        case .bottom:
            CGPoint(x: cropFrame.midX, y: cropFrame.maxY)
        case .left:
            CGPoint(x: cropFrame.minX, y: cropFrame.midY)
        case .right:
            CGPoint(x: cropFrame.maxX, y: cropFrame.midY)
        }
    }

    private func baseImage(fittedSize: CGSize) -> some View {
        previewImage
            .resizable()
            .border(.orange, width: photoEditConfiguration.showFrames ? 2 : 0)
            .scaledToFit()
            .scaleEffect(LosslessEditGeometry.rotationFitScale(for: fittedSize, angle: edits.rotation))
            .rotationEffect(edits.rotation)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private func outsideCropEffectImage(fittedSize: CGSize) -> some View {
        baseImage(fittedSize: fittedSize)
            .saturation(max(0, 1 - desaturateAmount))
            .blur(radius: blurRadius)
    }

    private func beginCropGesture(from cropFrame: CGRect) {
        if cropGestureStartFrame == nil {
            cropGestureStartFrame = cropFrame
        }
    }

    private func effectiveCropFrame(visibleImageSize: CGSize) -> CGRect {
        if let draftCropFrame, draftCropFrame.width > 1, draftCropFrame.height > 1 {
            return draftCropFrame
        }

        if let crop = edits.crop?.standardized,
           crop.width > minimumStoredCropDimension,
           crop.height > minimumStoredCropDimension {
            return LosslessEditGeometry.croppedFrame(
                from: crop,
                in: canvasSize,
                visibleImageSize: visibleImageSize
            )
        }

        return LosslessEditGeometry.uncroppedFrame(
            in: canvasSize,
            visibleImageSize: visibleImageSize,
            rotation: edits.rotation
        )
    }

    private func updateCropFrame(
        for constraint: CropConstraint,
        from cropFrame: CGRect,
        visibleImageSize: CGSize
    ) {
        guard let ratio = constraint.ratio else {
            commitConstrainedCropFrame(cropFrame, moving: .all, visibleImageSize: visibleImageSize)
            return
        }

        let adjusted = CropFrameMutation.aspectRatioAdjustedCropFrame(cropFrame, ratio: ratio)
        commitConstrainedCropFrame(adjusted, moving: .all, visibleImageSize: visibleImageSize)
    }

    private func commitConstrainedCropFrame(
        _ cropFrame: CGRect,
        moving: CropFrameMutation.MovingEdges,
        visibleImageSize: CGSize
    ) {
        let constrained = CropFrameMutation.constrainedCropFrame(
            cropFrame,
            moving: moving,
            within: cropWorkspaceRect,
            visibleImageSize: visibleImageSize,
            rotation: edits.rotation,
            cropConstraint: edits.cropConstraint
        )
        commitCropFrame(constrained, visibleImageSize: visibleImageSize)
    }

    private func commitCropFrame(_ cropFrame: CGRect, visibleImageSize: CGSize) {
        let clamped = CropFrameMutation.clamped(cropFrame: cropFrame.standardized, to: cropWorkspaceRect)
        draftCropFrame = clamped
        edits.crop = LosslessEditGeometry.normalizedCrop(
            from: clamped,
            in: canvasSize,
            visibleImageSize: visibleImageSize
        )
    }

    private func updateCropFrame(
        byTranslatingFrom cropFrame: CGRect,
        translation: CGSize,
        visibleImageSize: CGSize
    ) {
        let updated = CropFrameMutation.translatedCropFrame(cropFrame, by: translation)
        commitConstrainedCropFrame(updated, moving: .all, visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(
        byResizing handle: CropCornerHandle,
        from cropFrame: CGRect,
        translation: CGSize,
        visibleImageSize: CGSize
    ) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize,
            cropConstraint: edits.cropConstraint
        )
        commitConstrainedCropFrame(updated, moving: .corner(handle), visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(
        byResizing handle: CropEdgeHandle,
        from cropFrame: CGRect,
        translation: CGSize,
        visibleImageSize: CGSize
    ) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize,
            cropConstraint: edits.cropConstraint
        )
        commitConstrainedCropFrame(updated, moving: .edge(handle), visibleImageSize: visibleImageSize)
    }

    private var blurRadius: CGFloat {
        for effect in photoEditConfiguration.croppingEffects {
            if case let .blur(radius) = effect { return max(0, CGFloat(radius)) }
        }
        return 0
    }

    private var desaturateAmount: Double {
        for effect in photoEditConfiguration.croppingEffects {
            if case let .desaturate(amount) = effect { return max(0, min(1, amount)) }
        }
        return 0
    }

    private var dimOpacity: Double {
        for effect in photoEditConfiguration.croppingEffects {
            if case let .dim(opacity) = effect { return max(0, min(1, opacity)) }
        }
        return 0
    }

    private var previewImage: Image {
        let adjustedImage = image.applyingColorAdjustments(using: edits, targetSize: canvasSize)
        return Image(uiImage: adjustedImage!)
    }
}

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
        let boundary = RotatedImageBoundary(
            in: bounds,
            visibleImageSize: visibleImageSize,
            rotation: rotation
        )

        switch moving {
        case .all:
            var constrained = clamped(cropFrame: cropFrame.standardized, to: bounds)
            constrained = clampTranslatedCropFrame(constrained, within: boundary)
            return clamped(cropFrame: constrained, to: bounds)
        case .corner, .edge:
            var constrained = cropFrame.standardized
            if let ratio = cropConstraint.ratio {
                constrained = clampAspectLockedCropFrame(
                    constrained,
                    moving: moving,
                    within: boundary,
                    ratio: ratio
                )
            } else {
                for edge in moving.affectedEdges {
                    switch edge {
                    case .top:
                        constrained = clampTopEdge(of: constrained, within: boundary)
                    case .bottom:
                        constrained = clampBottomEdge(of: constrained, within: boundary)
                    case .left:
                        constrained = clampLeftEdge(of: constrained, within: boundary)
                    case .right:
                        constrained = clampRightEdge(of: constrained, within: boundary)
                    }
                }
            }
            return constrained
        }
    }

    private static func clampTranslatedCropFrame(
        _ cropFrame: CGRect,
        within boundary: RotatedImageBoundary
    ) -> CGRect {
        var constrained = cropFrame

        return constrained
    }

    private static func clampAspectLockedCropFrame(
        _ cropFrame: CGRect,
        moving: MovingEdges,
        within boundary: RotatedImageBoundary,
        ratio: CGFloat
    ) -> CGRect {
        switch moving {
        case let .corner(handle):
            clampAspectLockedCornerCropFrame(cropFrame, handle: handle, within: boundary, ratio: ratio)
        case let .edge(handle):
            clampAspectLockedEdgeCropFrame(cropFrame, handle: handle, within: boundary, ratio: ratio)
        case .all:
            clampTranslatedCropFrame(cropFrame, within: boundary)
        }
    }

    private static func clampAspectLockedCornerCropFrame(
        _ cropFrame: CGRect,
        handle: CropCornerHandle,
        within boundary: RotatedImageBoundary,
        ratio: CGFloat
    ) -> CGRect {
        let proposedWidth = cropFrame.width

        return binarySearchValidFrame(
            initialWidthOrHeight: proposedWidth,
            minimumValue: 1,
            moving: .corner(handle)
        ) { value in
            let height = value / ratio

            switch handle {
            case .topLeft:
                let anchor = CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
                return CGRect(x: anchor.x - value, y: anchor.y - height, width: value, height: height)
            case .topRight:
                let anchor = CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
                return CGRect(x: anchor.x, y: anchor.y - height, width: value, height: height)
            case .bottomLeft:
                let anchor = CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
                return CGRect(x: anchor.x - value, y: anchor.y, width: value, height: height)
            case .bottomRight:
                let anchor = CGPoint(x: cropFrame.minX, y: cropFrame.minY)
                return CGRect(x: anchor.x, y: anchor.y, width: value, height: height)
            }
        } validator: { candidate in
            edgesAreValid(candidate, for: .corner(handle), within: boundary)
        }
    }

    private static func clampAspectLockedEdgeCropFrame(
        _ cropFrame: CGRect,
        handle: CropEdgeHandle,
        within boundary: RotatedImageBoundary,
        ratio: CGFloat
    ) -> CGRect {
        let center = CGPoint(x: cropFrame.midX, y: cropFrame.midY)

        switch handle {
        case .top:
            return binarySearchValidFrame(
                initialWidthOrHeight: cropFrame.height,
                minimumValue: 1,
                moving: .edge(handle)
            ) { value in
                let width = value * ratio
                return CGRect(
                    x: center.x - width / 2,
                    y: cropFrame.maxY - value,
                    width: width,
                    height: value
                )
            } validator: { candidate in
                edgesAreValid(candidate, for: .edge(handle), within: boundary)
            }
        case .bottom:
            return binarySearchValidFrame(
                initialWidthOrHeight: cropFrame.height,
                minimumValue: 1,
                moving: .edge(handle)
            ) { value in
                let width = value * ratio
                return CGRect(
                    x: center.x - width / 2,
                    y: cropFrame.minY,
                    width: width,
                    height: value
                )
            } validator: { candidate in
                edgesAreValid(candidate, for: .edge(handle), within: boundary)
            }
        case .left:
            return binarySearchValidFrame(
                initialWidthOrHeight: cropFrame.width,
                minimumValue: 1,
                moving: .edge(handle)
            ) { value in
                let height = value / ratio
                return CGRect(
                    x: cropFrame.maxX - value,
                    y: center.y - height / 2,
                    width: value,
                    height: height
                )
            } validator: { candidate in
                edgesAreValid(candidate, for: .edge(handle), within: boundary)
            }
        case .right:
            return binarySearchValidFrame(
                initialWidthOrHeight: cropFrame.width,
                minimumValue: 1,
                moving: .edge(handle)
            ) { value in
                let height = value / ratio
                return CGRect(
                    x: cropFrame.minX,
                    y: center.y - height / 2,
                    width: value,
                    height: height
                )
            } validator: { candidate in
                edgesAreValid(candidate, for: .edge(handle), within: boundary)
            }
        }
    }

    private static func clampTopEdge(of cropFrame: CGRect, within boundary: RotatedImageBoundary) -> CGRect {
        let maxY = cropFrame.maxY
        let minY = max(cropFrame.minY, boundary.maximumAllowedFrame.minY)
        return CGRect(x: cropFrame.minX, y: minY, width: cropFrame.width, height: maxY - minY)
    }

    private static func clampBottomEdge(of cropFrame: CGRect, within boundary: RotatedImageBoundary) -> CGRect {
        let maxY = min(cropFrame.maxY, boundary.maximumAllowedFrame.maxY)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: cropFrame.width, height: maxY - cropFrame.minY)
    }

    private static func clampLeftEdge(of cropFrame: CGRect, within boundary: RotatedImageBoundary) -> CGRect {
        let maxX = cropFrame.maxX
        let minX = max(cropFrame.minX, boundary.maximumAllowedFrame.minX)
        return CGRect(x: minX, y: cropFrame.minY, width: maxX - minX, height: cropFrame.height)
    }

    private static func clampRightEdge(of cropFrame: CGRect, within boundary: RotatedImageBoundary) -> CGRect {
        let maxX = min(cropFrame.maxX, boundary.maximumAllowedFrame.maxX)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: maxX - cropFrame.minX, height: cropFrame.height)
    }

    private static func binarySearchValidFrame(
        initialWidthOrHeight: CGFloat,
        minimumValue: CGFloat,
        moving: MovingEdges,
        builder: (CGFloat) -> CGRect,
        validator: (CGRect) -> Bool
    ) -> CGRect {
        var low = minimumValue
        var high = initialWidthOrHeight
        var best = builder(minimumValue)

        if validator(builder(high)) {
            return builder(high)
        }

        for _ in 0..<24 {
            let mid = (low + high) / 2
            let candidate = builder(mid)
            if validator(candidate) {
                best = candidate
                low = mid
            } else {
                high = mid
            }
        }

        return best
    }

    private static func edgesAreValid(
        _ cropFrame: CGRect,
        for moving: MovingEdges,
        within boundary: RotatedImageBoundary
    ) -> Bool {
        moving.affectedEdges.allSatisfy { edgeIsValid($0, in: cropFrame, within: boundary) }
    }

    private static func edgeIsValid(
        _ edge: CropEdgeHandle,
        in cropFrame: CGRect,
        within boundary: RotatedImageBoundary
    ) -> Bool {
        switch edge {
        case .top:
            return boundary.contains(CGPoint(x: cropFrame.minX, y: cropFrame.minY))
                && boundary.contains(CGPoint(x: cropFrame.maxX, y: cropFrame.minY))
        case .bottom:
            return boundary.contains(CGPoint(x: cropFrame.minX, y: cropFrame.maxY))
                && boundary.contains(CGPoint(x: cropFrame.maxX, y: cropFrame.maxY))
        case .left:
            return boundary.contains(CGPoint(x: cropFrame.minX, y: cropFrame.minY))
                && boundary.contains(CGPoint(x: cropFrame.minX, y: cropFrame.maxY))
        case .right:
            return boundary.contains(CGPoint(x: cropFrame.maxX, y: cropFrame.minY))
                && boundary.contains(CGPoint(x: cropFrame.maxX, y: cropFrame.maxY))
        }
    }
}

private struct RotatedImageBoundary {
    let corners: [CGPoint]
    let maximumAllowedFrame: CGRect

    init(
        in bounds: CGRect,
        visibleImageSize: CGSize,
        rotation: Angle
    ) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let halfWidth = visibleImageSize.width / 2
        let halfHeight = visibleImageSize.height / 2
        let cosine = cos(rotation.radians)
        let sine = sin(rotation.radians)

        corners = [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight)
        ].map { point in
            CGPoint(
                x: center.x + (point.x * cosine) - (point.y * sine),
                y: center.y + (point.x * sine) + (point.y * cosine)
            )
        }

        let minX = corners.map(\.x).min() ?? bounds.minX
        let maxX = corners.map(\.x).max() ?? bounds.maxX
        let minY = corners.map(\.y).min() ?? bounds.minY
        let maxY = corners.map(\.y).max() ?? bounds.maxY

        maximumAllowedFrame = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    func contains(_ point: CGPoint, epsilon: CGFloat = 0.5) -> Bool {
        point.x >= maximumAllowedFrame.minX - epsilon &&
        point.x <= maximumAllowedFrame.maxX + epsilon &&
        point.y >= maximumAllowedFrame.minY - epsilon &&
        point.y <= maximumAllowedFrame.maxY + epsilon
    }
}

#Preview {
    let photoEditConfiguration = PhotoEditConfiguration(
        croppingEffects: CroppingEffectSet([.dim(opacity: 0.4)])
    )
    CroppingView(
        image: UIImage(systemName: "photo")!,
        canvasSize: CGSize(width: 390, height: 640),
        edits: .constant(LosslessEdits(crop: nil, rotation: .degrees(6))),
        photoEditConfiguration: photoEditConfiguration
    )
    .background(Color.black)
}
