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

    init(image: UIImage, canvasSize: CGSize, edits: Binding<LosslessEdits>, photoEditConfiguration: PhotoEditConfiguration) {
        self.image = image
        self.canvasSize = canvasSize
        _edits = edits
        self.photoEditConfiguration = photoEditConfiguration
    }

    var body: some View {
        let layoutRotation = edits.rotation.nearestQuarterTurn
        let tiltRotation = edits.rotation - layoutRotation
        let renderRotation = edits.rotation
        let layoutImageSize = image.size.rotatedForLayout(by: layoutRotation)
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: layoutImageSize, in: canvasSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: tiltRotation)
        let currentCropFrame = effectiveCropFrame(visibleImageSize: visibleImageSize)

        ZStack {
            baseImage(
                fittedSize: fittedSize,
                renderRotation: renderRotation,
                layoutRotation: layoutRotation,
                tiltRotation: tiltRotation
            )

            if blurRadius > 0 || desaturateAmount > 0 {
                outsideCropEffectImage(
                    fittedSize: fittedSize,
                    renderRotation: renderRotation,
                    layoutRotation: layoutRotation,
                    tiltRotation: tiltRotation
                )
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
        .onChange(of: edits.rotation) { _, _ in
            draftCropFrame = nil
            cropGestureStartFrame = nil
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

    private var cropBoundsRotation: Angle {
        edits.rotation - edits.rotation.nearestQuarterTurn
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

    private func baseImage(
        fittedSize: CGSize,
        renderRotation: Angle,
        layoutRotation: Angle,
        tiltRotation: Angle
    ) -> some View {
        let renderSize = fittedSize.rotatedForLayout(by: -layoutRotation)
        return previewImage
            .resizable()
            .border(.orange, width: photoEditConfiguration.showFrames ? 2 : 0)
            .scaledToFit()
            .frame(width: renderSize.width, height: renderSize.height)
            .scaleEffect(LosslessEditGeometry.rotationFitScale(for: fittedSize, angle: tiltRotation))
            .rotationEffect(renderRotation)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private func outsideCropEffectImage(
        fittedSize: CGSize,
        renderRotation: Angle,
        layoutRotation: Angle,
        tiltRotation: Angle
    ) -> some View {
        baseImage(
            fittedSize: fittedSize,
            renderRotation: renderRotation,
            layoutRotation: layoutRotation,
            tiltRotation: tiltRotation
        )
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
            rotation: cropBoundsRotation
        )
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
            rotation: cropBoundsRotation,
            cropConstraint: edits.cropConstraint
        )
        commitCropFrame(constrained, visibleImageSize: visibleImageSize)
    }

    private func commitCropFrame(_ cropFrame: CGRect, visibleImageSize: CGSize) {
        let clamped = cropBounds(visibleImageSize: visibleImageSize).clamped(cropFrame.standardized)
        draftCropFrame = clamped
        edits.crop = LosslessEditGeometry.normalizedCrop(
            from: clamped,
            in: canvasSize,
            visibleImageSize: visibleImageSize
        )
    }

    private func cropBounds(visibleImageSize: CGSize) -> CropBounds {
        CropBounds(
            in: cropWorkspaceRect,
            visibleImageSize: visibleImageSize,
            rotation: cropBoundsRotation
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
        let adjustedImage = image.applyingColorAdjustments(using: edits, targetSize: canvasSize) ?? image
        return Image(uiImage: adjustedImage)
    }
}

private extension CGSize {
    func rotatedForLayout(by angle: Angle) -> CGSize {
        let normalizedQuarterTurns = angle.normalizedQuarterTurns
        switch normalizedQuarterTurns {
        case 1, 3:
            return CGSize(width: height, height: width)
        default:
            return self
        }
    }
}

private extension Angle {
    static prefix func - (angle: Angle) -> Angle {
        .degrees(-angle.degrees)
    }

    static func - (lhs: Angle, rhs: Angle) -> Angle {
        .degrees(lhs.degrees - rhs.degrees)
    }

    static func + (lhs: Angle, rhs: Angle) -> Angle {
        .degrees(lhs.degrees + rhs.degrees)
    }

    var nearestQuarterTurn: Angle {
        .degrees(Double(roundedQuarterTurns) * 90)
    }

    var normalizedQuarterTurns: Int {
        ((roundedQuarterTurns % 4) + 4) % 4
    }

    private var roundedQuarterTurns: Int {
        Int((degrees / 90).rounded())
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
