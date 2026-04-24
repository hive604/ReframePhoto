//
//  ReframePhotoEditor.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import os

struct ReframePhotoEditor: View {
    static let checkmark = "checkmark.circle.fill"
    static let xmark = "xmark.circle.fill"

    private static let logger = Logger(subsystem: "com.hive604.ReframePhoto", category: "ReframePhotoEditor")
    private let minimumNormalizedCropSize: CGFloat = 0.15
    private let minimumStoredCropDimension: CGFloat = 0.0001

    private static func log(_ str: String) {
        logger.debug("\(str)")
    }

    let image: Image
    let imageSize: CGSize
    @Binding var edits: LosslessEdits
    let onCancel: (() -> Void)?
    let onConfirm: (() -> Void)?

    @State private var draftEdits: LosslessEdits
    @State private var tool: ToolMode = .tilt

    @State private var draftCropFrame: CGRect?
    @State private var cropGestureStartFrame: CGRect?

    let croppingEffects: CroppingEffectSet

    private enum ToolMode: String, CaseIterable, Identifiable {
        case tilt
        case crop

        var id: String { rawValue }
    }

    init(
        image: Image,
        imageSize: CGSize,
        edits: Binding<LosslessEdits>,
        croppingEffects: CroppingEffectSet = CroppingEffectSet([.dim(opacity: 0.4)]),
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self.image = image
        self.imageSize = imageSize
        _edits = edits
        self.croppingEffects = croppingEffects
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftEdits = State(initialValue: edits.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            editorImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .onChange(of: edits) { _, newValue in
            Self.log("edits -> \(edits)")
            draftEdits = newValue
            draftCropFrame = nil
            cropGestureStartFrame = nil
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Layout

private extension ReframePhotoEditor {
    var topBar: some View {
        HStack {
            cancelButton

            Spacer()

            Picker("Tool", selection: $tool) {
                Text("Tilt").tag(ToolMode.tilt)
                Text("Crop").tag(ToolMode.crop)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

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
                        fittedSize: fittedSize,
                        rotation: draftEdits.rotation,
                        geometrySize: geometry.size,
                        cropFrame: currentCropFrame,
                        croppingEffects: croppingEffects,
                        onReset: {
                            draftEdits.crop = nil
                            draftCropFrame = nil
                        },
                        onTranslate: { (translation: CGSize) in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }

                            updateCropFrame(
                                byTranslatingFrom: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                visibleImageSize: visibleImageSize
                            )
                        },
                        onResizeCorner: { (handle: CropCornerHandle, translation: CGSize) in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }

                            updateCropFrame(
                                byResizing: handle,
                                from: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                visibleImageSize: visibleImageSize
                            )
                        },
                        onResizeEdge: { (handle: CropEdgeHandle, translation: CGSize) in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }
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
                    TiltingView(
                        image: image,
                        imageSize: imageSize,
                        geometrySize: geometry.size,
                        rotationDegrees: rotationDegreesBinding,
                        cropFrame: currentCropFrame
                    )
                }
            }
            .onChange(of: tool) { _, newValue in
                Self.log("tool -> \(newValue)")
                if newValue == .crop {
                    draftCropFrame = effectiveCropFrame(in: geometry.size, visibleImageSize: visibleImageSize)
                } else {
                    draftCropFrame = nil
                    cropGestureStartFrame = nil
                }
            }
        }
#if DEBUG
        .border(.yellow, width: 1)
#endif
    }

}

// MARK: - Crop State

private extension ReframePhotoEditor {
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

private extension ReframePhotoEditor {
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
        commitCropFrame(updated, geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(byResizing handle: CropCornerHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, visibleImageSize: CGSize) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize
        )
        commitCropFrame(updated, geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }

    private func updateCropFrame(byResizing handle: CropEdgeHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, visibleImageSize: CGSize) {
        let updated = CropFrameMutation.resizedCropFrame(
            cropFrame,
            byResizing: handle,
            translation: translation,
            minimumNormalizedCropSize: minimumNormalizedCropSize,
            visibleImageSize: visibleImageSize
        )
        commitCropFrame(updated, geometrySize: geometrySize, visibleImageSize: visibleImageSize)
    }
}


// MARK: - Crop Frame Mutation Helper

private enum CropFrameMutation {
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
}

// MARK: - Bindings

private extension ReframePhotoEditor {
    var rotationDegreesBinding: Binding<Double> {
        Binding(
            get: { draftEdits.rotation.degrees },
            set: {
                draftEdits.rotation = .degrees($0)
                Self.log("rotate now \($0)")
            }
        )
    }
}

// MARK: - Buttons

private extension ReframePhotoEditor {
    var cancelButton: some View {
        CircularSymbolButton(systemName: Self.xmark) {
            Self.log("tapped cancel")
            draftEdits = edits
            tool = .tilt
            draftCropFrame = nil
            cropGestureStartFrame = nil
            onCancel?()
        }
        .accessibilityLabel("Cancel")
    }

    var acceptButton: some View {
        CircularSymbolButton(systemName: Self.checkmark) {
            Self.log("tapped accept")
            edits = draftEdits
            tool = .tilt
            draftCropFrame = nil
            cropGestureStartFrame = nil
            onConfirm?()
        }
        .accessibilityLabel("OK")
    }
}

// MARK: - Preview

#Preview {
    ReframePhotoEditor(
        image: Image(systemName: "photo"),
        imageSize: CGSize(width: 1200, height: 800),
        edits: .constant(LosslessEdits(crop: nil, rotation: .zero)),
        croppingEffects: CroppingEffectSet([.blur(radius: 5)])
    )
}
