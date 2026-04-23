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

    private let logger = Logger(subsystem: "com.hive604.ReframePhoto", category: "ReframePhotoEditor")

    func log(_ str: String) {
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
    private let cropHandleSize: CGFloat = 28
    private let minimumNormalizedCropSize: CGFloat = 0.15


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
            self.log("edits -> \(edits)")
            draftEdits = newValue
            draftCropFrame = nil
            cropGestureStartFrame = nil
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Content

private extension ReframePhotoEditor {
    var editorImage: some View {
        GeometryReader { geometry in
            let fittedSize = aspectFitSize(for: imageSize, in: geometry.size)
            let visibleImageSize = visibleImageSize(for: fittedSize, angle: draftEdits.rotation)
            let currentCropFrame = effectiveCropFrame(in: geometry.size, displayedImageSize: visibleImageSize)

            ZStack {
                if tool == .crop {
                    CroppingView(
                        image: image,
                        fittedSize: fittedSize,
                        rotation: draftEdits.rotation,
                        geometrySize: geometry.size,
                        displayedImageSize: visibleImageSize,
                        cropFrame: currentCropFrame,
                        cropHandleSize: cropHandleSize,
                        croppingEffects: croppingEffects,
                        onReset: {
                            draftEdits.crop = nil
                            draftCropFrame = nil
                        },
                        onTranslate: { translation in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }

                            updateCropFrame(
                                byTranslatingFrom: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                displayedImageSize: visibleImageSize
                            )
                        },
                        onResize: { handle, translation in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }

                            updateCropFrame(
                                byResizing: handle,
                                from: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                displayedImageSize: visibleImageSize
                            )
                        },
                        onResizeEdge: { handle, translation in
                            if cropGestureStartFrame == nil {
                                cropGestureStartFrame = currentCropFrame
                            }
                            updateCropFrame(
                                byResizing: handle,
                                from: cropGestureStartFrame ?? currentCropFrame,
                                translation: translation,
                                geometrySize: geometry.size,
                                displayedImageSize: visibleImageSize
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
                self.log("tool -> \(newValue)")
                if newValue == .crop {
                    draftCropFrame = effectiveCropFrame(in: geometry.size, displayedImageSize: visibleImageSize)
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
    func visibleImageSize(for fittedSize: CGSize, angle: Angle) -> CGSize {
        let fitScale = rotationFitScale(for: fittedSize, angle: angle)

        return CGSize(
            width: fittedSize.width * fitScale,
            height: fittedSize.height * fitScale
        )
    }


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


// (tiltImageView, cropOverlay, and cropHandleView removed)
}

// MARK: - Controls

private extension ReframePhotoEditor {

    func effectiveCropFrame(in geometrySize: CGSize, displayedImageSize: CGSize) -> CGRect {
        if let draftCropFrame, draftCropFrame.width > 1, draftCropFrame.height > 1 {
            return draftCropFrame
        }

        if let crop = validStoredCrop {
            return cropFrame(from: crop, in: geometrySize, displayedImageSize: displayedImageSize)
        }

        return fullTiltedCropFrame(in: geometrySize, displayedImageSize: displayedImageSize)
    }

    var validStoredCrop: CGRect? {
        guard let crop = draftEdits.crop?.standardized else { return nil }
        guard crop.width > 0.0001, crop.height > 0.0001 else { return nil }
        return crop
    }

    func fullTiltedCropFrame(in geometrySize: CGSize, displayedImageSize: CGSize) -> CGRect {
        let rotatedSize = rotatedBoundingSize(for: displayedImageSize, angle: draftEdits.rotation)

        return CGRect(
            x: (geometrySize.width - rotatedSize.width) / 2,
            y: (geometrySize.height - rotatedSize.height) / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )
    }

    func cropFrame(from crop: CGRect, in geometrySize: CGSize, displayedImageSize: CGSize) -> CGRect {
        let center = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)

        let minX = center.x + (crop.minX * displayedImageSize.width)
        let maxX = center.x + (crop.maxX * displayedImageSize.width)
        let minY = center.y + (crop.minY * displayedImageSize.height)
        let maxY = center.y + (crop.maxY * displayedImageSize.height)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func normalizedCrop(from cropFrame: CGRect, in geometrySize: CGSize, displayedImageSize: CGSize) -> CGRect {
        let center = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)

        return CGRect(
            x: (cropFrame.minX - center.x) / displayedImageSize.width,
            y: (cropFrame.minY - center.y) / displayedImageSize.height,
            width: cropFrame.width / displayedImageSize.width,
            height: cropFrame.height / displayedImageSize.height
        )
    }

    private func position(for handle: CropCornerHandle, in cropFrame: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .topRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .bottomLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .bottomRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        }
    }

    func updateCropFrame(byTranslatingFrom cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, displayedImageSize: CGSize) {
        let candidate = cropFrame.offsetBy(dx: translation.width, dy: translation.height)
        let clamped = clamp(cropFrame: candidate, in: geometrySize)
        draftCropFrame = clamped
        draftEdits.crop = normalizedCrop(from: clamped, in: geometrySize, displayedImageSize: displayedImageSize)
    }

    private func updateCropFrame(byResizing handle: CropCornerHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, displayedImageSize: CGSize) {
        var updated = cropFrame
        let minimumWidth = displayedImageSize.width * minimumNormalizedCropSize
        let minimumHeight = displayedImageSize.height * minimumNormalizedCropSize

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

        let clamped = clamp(cropFrame: updated.standardized, in: geometrySize)
        draftCropFrame = clamped
        draftEdits.crop = normalizedCrop(from: clamped, in: geometrySize, displayedImageSize: displayedImageSize)
    }

    // Edge-resize variant used when dragging a single edge handle
    private func updateCropFrame(byResizing handle: CropEdgeHandle, from cropFrame: CGRect, translation: CGSize, geometrySize: CGSize, displayedImageSize: CGSize) {
        var updated = cropFrame
        let minimumWidth = displayedImageSize.width * minimumNormalizedCropSize
        let minimumHeight = displayedImageSize.height * minimumNormalizedCropSize

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

        // Enforce minimums per affected axis
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

        let clamped = clamp(cropFrame: updated.standardized, in: geometrySize)
        draftCropFrame = clamped
        draftEdits.crop = normalizedCrop(from: clamped, in: geometrySize, displayedImageSize: displayedImageSize)
    }

    func clamp(cropFrame: CGRect, in geometrySize: CGSize) -> CGRect {
        var clamped = cropFrame

        if clamped.minX < 0 {
            clamped.origin.x = 0
        }
        if clamped.minY < 0 {
            clamped.origin.y = 0
        }
        if clamped.maxX > geometrySize.width {
            clamped.origin.x = geometrySize.width - clamped.width
        }
        if clamped.maxY > geometrySize.height {
            clamped.origin.y = geometrySize.height - clamped.height
        }

        return clamped
    }

    func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
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

    func rotationFitScale(for size: CGSize, angle: Angle) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        let rotatedSize = rotatedBoundingSize(for: size, angle: angle)
        guard rotatedSize.width > 0, rotatedSize.height > 0 else { return 1 }

        let horizontalScale = size.width / rotatedSize.width
        let verticalScale = size.height / rotatedSize.height

        return min(horizontalScale, verticalScale, 1)
    }

    func rotatedBoundingSize(for size: CGSize, angle: Angle) -> CGSize {
        let radians = angle.radians
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))

        return CGSize(
            width: size.width * absoluteCosine + size.height * absoluteSine,
            height: size.width * absoluteSine + size.height * absoluteCosine
        )
    }

    var rotationDegreesBinding: Binding<Double> {
        Binding(
            get: { draftEdits.rotation.degrees },
            set: {
                draftEdits.rotation = .degrees($0)
                self.log("rotate now \($0)")
            }
        )
    }

    var cancelButton: some View {
        circularSymbolButton(
            systemName: Self.xmark,
            accessibilityLabel: "Cancel"
        ) {
            log("tapped cancel")
            draftEdits = edits
            tool = .tilt
            draftCropFrame = nil
            cropGestureStartFrame = nil
            onCancel?()
        }
    }

    var acceptButton: some View {
        circularSymbolButton(
            systemName: Self.checkmark,
            accessibilityLabel: "OK"
        ) {
            log("tapped accept")
            edits = draftEdits
            tool = .tilt
            draftCropFrame = nil
            cropGestureStartFrame = nil
            onConfirm?()
        }
    }

    @ViewBuilder
    func circularSymbolButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.ultraThickMaterial, in: Circle())
        }
        .buttonStyle(CircularSymbolButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Styles

private struct CircularSymbolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background {
                Circle()
                    .fill(.black.opacity(configuration.isPressed ? 0.8 : 0.6))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ReframePhotoEditor(
        image: Image(systemName: "photo"),
        imageSize: CGSize(width: 1200, height: 800),
        edits: .constant(LosslessEdits(crop: nil, rotation: .zero)),
        croppingEffects: CroppingEffectSet([.blur(radius: 5)])
    )
}
