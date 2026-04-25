//
//  PhotoEditor.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import os

public struct PhotoEditor: View {
    static let checkmark = "checkmark.circle.fill"
    static let xmark = "xmark.circle.fill"

    private static let logger = Logger(subsystem: "com.hive604.Reframe", category: "PhotoEditor")
    private let minimumNormalizedCropSize: CGFloat = 0.15
    private let minimumStoredCropDimension: CGFloat = 0.0001

    private static func log(_ str: String) {
        logger.debug("\(str)")
    }

    let image: Image
    let sourceUIImage: UIImage?
    let imageSize: CGSize
    @Binding var edits: LosslessEdits
    let onCancel: (() -> Void)?
    let onConfirm: (() -> Void)?

    @State private var draftEdits: LosslessEdits
    @State private var tool: ToolMode = .adjust

    @State private var draftCropFrame: CGRect?
    @State private var cropGestureStartFrame: CGRect?

    let croppingEffects: CroppingEffectSet

    private enum ToolMode: String, CaseIterable, Identifiable {
        case crop
        case adjust

        var id: String { rawValue }
    }

    public init(
        uiImage: UIImage,
        edits: Binding<LosslessEdits>,
        croppingEffects: CroppingEffectSet = CroppingEffectSet([.dim(opacity: 0.4)]),
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        image = Image(uiImage: uiImage)
        sourceUIImage = uiImage
        imageSize = uiImage.size
        _edits = edits
        self.croppingEffects = croppingEffects
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftEdits = State(initialValue: edits.wrappedValue)
    }

    public init(
        image: Image,
        imageSize: CGSize,
        edits: Binding<LosslessEdits>,
        croppingEffects: CroppingEffectSet = CroppingEffectSet([.dim(opacity: 0.4)]),
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self.image = image
        sourceUIImage = nil
        self.imageSize = imageSize
        _edits = edits
        self.croppingEffects = croppingEffects
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftEdits = State(initialValue: edits.wrappedValue)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .zIndex(1)

            editorImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)
        }
        .background(Color.black)
        .onChange(of: edits) { _, newValue in
            Self.log("edits -> \(edits)")
            draftEdits = newValue
            resetTransientCropState()
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Layout

private extension PhotoEditor {
    var topBar: some View {
        HStack {
            cancelButton

            Spacer()

            Picker("Tool", selection: $tool) {
                Text("Crop").tag(ToolMode.crop)
                Text("Adjust").tag(ToolMode.adjust)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            acceptButton
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    var editorImage: some View {
        GeometryReader { geometry in
            let fittedSize = LosslessEditGeometry.aspectFitSize(for: imageSize, in: geometry.size)
            let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: draftEdits.rotation)
            let currentCropFrame = effectiveCropFrame(in: geometry.size, visibleImageSize: visibleImageSize)

            ZStack {
                if tool == .crop {
                    CroppingView(
                        image: image,
                        sourceUIImage: sourceUIImage,
                        fittedSize: fittedSize,
                        geometrySize: geometry.size,
                        edits: $draftEdits,
                        cropFrame: currentCropFrame,
                        croppingEffects: croppingEffects,
                        onReset: {
                            draftEdits.crop = nil
                            draftCropFrame = nil
                        },
                        onTranslate: { (translation: CGSize) in
                            beginCropGesture(from: currentCropFrame)
                            updateCropFrame(
                                byTranslatingFrom: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                visibleImageSize: visibleImageSize
                            )
                        },
                        onResizeCorner: { (handle: CropCornerHandle, translation: CGSize) in
                            beginCropGesture(from: currentCropFrame)
                            updateCropFrame(
                                byResizing: handle,
                                from: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                visibleImageSize: visibleImageSize
                            )
                        },
                        onResizeEdge: { (handle: CropEdgeHandle, translation: CGSize) in
                            beginCropGesture(from: currentCropFrame)
                            updateCropFrame(
                                byResizing: handle,
                                from: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                visibleImageSize: visibleImageSize
                            )
                        },
                        onEndGesture: {
                            cropGestureStartFrame = nil
                        }
                    )
                } else {
                    AdjustView(
                        image: image,
                        sourceUIImage: sourceUIImage,
                        imageSize: imageSize,
                        geometrySize: geometry.size,
                        edits: $draftEdits,
                        cropFrame: currentCropFrame
                    )
                }
            }
            .onChange(of: tool) { _, newValue in
                Self.log("tool -> \(newValue)")
                if newValue == .crop {
                    draftCropFrame = effectiveCropFrame(in: geometry.size, visibleImageSize: visibleImageSize)
                } else {
                    resetTransientCropState()
                }
            }
        }
#if DEBUG
        .border(.yellow, width: 1)
#endif
    }

}

// MARK: - Crop State

private extension PhotoEditor {
    func beginCropGesture(from cropFrame: CGRect) {
        if cropGestureStartFrame == nil {
            cropGestureStartFrame = cropFrame
        }
    }

    func resetTransientCropState() {
        draftCropFrame = nil
        cropGestureStartFrame = nil
    }

    func effectiveCropFrame(in geometrySize: CGSize, visibleImageSize: CGSize) -> CGRect {
        if let draftCropFrame, draftCropFrame.width > 1, draftCropFrame.height > 1 {
            return draftCropFrame
        }

        if let crop = draftEdits.crop?.standardized,
           crop.width > minimumStoredCropDimension,
           crop.height > minimumStoredCropDimension {
            return LosslessEditGeometry.croppedFrame(from: crop, in: geometrySize, visibleImageSize: visibleImageSize)
        }

        return LosslessEditGeometry.uncroppedFrame(
            in: geometrySize,
            visibleImageSize: visibleImageSize,
            rotation: draftEdits.rotation
        )
    }
}


// MARK: - Crop Mutation

private extension PhotoEditor {
    func commitConstrainedCropFrame(
        _ cropFrame: CGRect,
        moving: CropFrameMutation.MovingEdges,
        geometrySize: CGSize,
        visibleImageSize: CGSize
    ) {
        let constrained = CropFrameMutation.constrainedCropFrame(
            cropFrame,
            moving: moving,
            within: CGRect(origin: .zero, size: geometrySize),
            visibleImageSize: visibleImageSize,
            rotation: draftEdits.rotation
        )
        commitCropFrame(constrained, geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }

    func commitCropFrame(_ cropFrame: CGRect, geometrySize: CGSize, visibleImageSize: CGSize) {
        let bounds = CGRect(origin: .zero, size: geometrySize)
        let clamped = CropFrameMutation.clamped(cropFrame: cropFrame.standardized, to: bounds)
        draftCropFrame = clamped
        draftEdits.crop = LosslessEditGeometry.normalizedCrop(
            from: clamped,
            in: geometrySize,
            visibleImageSize: visibleImageSize
        )
    }

    func updateCropFrame(byTranslatingFrom cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, visibleImageSize: CGSize) {
        let updated = CropFrameMutation.translatedCropFrame(cropFrame, by: translation)
        commitConstrainedCropFrame(updated, moving: .all, geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(byResizing handle: CropCornerHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, visibleImageSize: CGSize) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize
        )
        commitConstrainedCropFrame(updated, moving: .corner(handle), geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(byResizing handle: CropEdgeHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, visibleImageSize: CGSize) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize
        )
        commitConstrainedCropFrame(updated, moving: .edge(handle), geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }
}


// MARK: - Crop Frame Mutation Helper

private enum CropFrameMutation {
    enum MovingEdges {
        case all
        case corner(CropCornerHandle)
        case edge(CropEdgeHandle)

        var affectedEdges: [CropEdgeHandle] {
            switch self {
            case .all:
                return [.top, .bottom, .left, .right]
            case let .corner(handle):
                switch handle {
                case .topLeft:
                    return [.top, .left]
                case .topRight:
                    return [.top, .right]
                case .bottomLeft:
                    return [.bottom, .left]
                case .bottomRight:
                    return [.bottom, .right]
                }
            case let .edge(handle):
                return [handle]
            }
        }
    }

    static func translatedCropFrame(_ cropFrame: CGRect, by translation: CGSize) -> CGRect {
        cropFrame.offsetBy(dx: translation.width, dy: translation.height)
    }

    static func resizedCropFrame(
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

    static func resizedCropFrame(
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
            case .right:
                break
            case .top, .bottom:
                break
            }
            updated.size.width = minimumWidth
        }

        if updated.height < minimumHeight {
            switch handle {
            case .top:
                updated.origin.y = cropFrame.maxY - minimumHeight
            case .bottom:
                break
            case .left, .right:
                break
            }
            updated.size.height = minimumHeight
        }

        return updated
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
        rotation: Angle
    ) -> CGRect {
        var constrained = clamped(cropFrame: cropFrame.standardized, to: bounds)
        let extrema = rotatedImageExtrema(
            in: bounds,
            visibleImageSize: visibleImageSize,
            rotation: rotation
        )

        switch moving {
        case .all:
            if constrained.minX < extrema.minX {
                constrained.origin.x = extrema.minX
            }
            if constrained.maxX > extrema.maxX {
                constrained.origin.x = extrema.maxX - constrained.width
            }
            if constrained.minY < extrema.minY {
                constrained.origin.y = extrema.minY
            }
            if constrained.maxY > extrema.maxY {
                constrained.origin.y = extrema.maxY - constrained.height
            }
        case .corner, .edge:
            for edge in moving.affectedEdges {
                switch edge {
                case .top:
                    constrained = clampTopEdge(of: constrained, toAtLeast: extrema.minY)
                case .bottom:
                    constrained = clampBottomEdge(of: constrained, toAtMost: extrema.maxY)
                case .left:
                    constrained = clampLeftEdge(of: constrained, toAtLeast: extrema.minX)
                case .right:
                    constrained = clampRightEdge(of: constrained, toAtMost: extrema.maxX)
                }
            }
        }

        return clamped(cropFrame: constrained, to: bounds)
    }

    private static func clampTopEdge(of cropFrame: CGRect, toAtLeast minimumY: CGFloat) -> CGRect {
        let maxY = cropFrame.maxY
        let minY = max(cropFrame.minY, minimumY)
        return CGRect(x: cropFrame.minX, y: minY, width: cropFrame.width, height: maxY - minY)
    }

    private static func clampBottomEdge(of cropFrame: CGRect, toAtMost maximumY: CGFloat) -> CGRect {
        let maxY = min(cropFrame.maxY, maximumY)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: cropFrame.width, height: maxY - cropFrame.minY)
    }

    private static func clampLeftEdge(of cropFrame: CGRect, toAtLeast minimumX: CGFloat) -> CGRect {
        let maxX = cropFrame.maxX
        let minX = max(cropFrame.minX, minimumX)
        return CGRect(x: minX, y: cropFrame.minY, width: maxX - minX, height: cropFrame.height)
    }

    private static func clampRightEdge(of cropFrame: CGRect, toAtMost maximumX: CGFloat) -> CGRect {
        let maxX = min(cropFrame.maxX, maximumX)
        return CGRect(x: cropFrame.minX, y: cropFrame.minY, width: maxX - cropFrame.minX, height: cropFrame.height)
    }

    private static func rotatedImageExtrema(
        in bounds: CGRect,
        visibleImageSize: CGSize,
        rotation: Angle
    ) -> CGRect {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let halfWidth = visibleImageSize.width / 2
        let halfHeight = visibleImageSize.height / 2
        let cosine = cos(rotation.radians)
        let sine = sin(rotation.radians)

        let corners = [
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

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

// MARK: - Buttons

private extension PhotoEditor {
    var cancelButton: some View {
        CircularSymbolButton(systemName: Self.xmark) {
            Self.log("tapped cancel")
            draftEdits = edits
            tool = .adjust
            resetTransientCropState()
            onCancel?()
        }
        .accessibilityLabel("Cancel")
    }

    var acceptButton: some View {
        CircularSymbolButton(systemName: Self.checkmark) {
            Self.log("tapped accept")
            edits = draftEdits
            tool = .adjust
            resetTransientCropState()
            onConfirm?()
        }
        .accessibilityLabel("OK")
    }
}

// MARK: - Preview

#Preview {
    PhotoEditor(
        image: Image(systemName: "photo"),
        imageSize: CGSize(width: 1200, height: 800),
        edits: .constant(LosslessEdits(crop: nil, rotation: .zero)),
        croppingEffects: CroppingEffectSet([.blur(radius: 5)])
    )
}
