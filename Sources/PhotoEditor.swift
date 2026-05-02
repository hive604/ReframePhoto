//
//  PhotoEditor.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import os

public struct PhotoEditor: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    static let checkmark = "checkmark.circle.fill"
    static let xmark = "xmark.circle.fill"

    private static let logger = Logger(subsystem: "com.hive604.Reframe", category: "PhotoEditor")
    private let minimumStoredCropDimension: CGFloat = 0.0001

    private static func log(_ str: String) {
        logger.debug("\(str)")
    }

    @Binding var edits: LosslessEdits
    let image: UIImage
    @State private var selectedSection: AdjustmentSection = .tone

    let save: (() -> Void)?
    @State private var draftEdits: LosslessEdits
    @State private var selectedAdjustment: PhotoEditConfiguration.Adjustment = .tilt

    let photoEditConfiguration: PhotoEditConfiguration

    private var cropIsAllowed: Bool {
        photoEditConfiguration.allowedAdjustments.contains(.crop)
    }

    private var hasAvailableAdjustments: Bool {
        !photoEditConfiguration.allowedAdjustments.isEmpty
    }

    private var showsCroppingMode: Bool {
        selectedAdjustment == .crop && cropIsAllowed
    }

    private var geometryCanvasBottomInset: CGFloat {
        guard selectedSection == .geometry, hasAvailableAdjustments else { return 0 }
        return horizontalSizeClass == .compact ? 148 : 212
    }

    public init(
        _ edits: Binding<LosslessEdits>,
        image: UIImage,
        configuration: PhotoEditConfiguration = PhotoEditConfiguration(),
        save: (() -> Void)? = nil
    ) {
        _edits = edits
        self.image = image
        self.photoEditConfiguration = configuration
        self.save = save

        _draftEdits = State(initialValue: edits.wrappedValue)
        let initialAdjustment = PhotoEditConfiguration.Adjustment.allCases.first(where: configuration.allowedAdjustments.contains) ?? .tilt
        _selectedAdjustment = State(initialValue: initialAdjustment)
        _selectedSection = State(initialValue: initialAdjustment.section)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .zIndex(1)

            editorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .onChange(of: edits) { _, newValue in
            Self.log("edits -> \(edits)")
            draftEdits = newValue
            sanitizeSelection()
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

            acceptButton
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    var editorContent: some View {
        GeometryReader { geometry in
            let canvasSize = CGSize(
                width: geometry.size.width,
                height: max(0, geometry.size.height - geometryCanvasBottomInset)
            )
            let fittedSize = LosslessEditGeometry.aspectFitSize(for: image.size, in: canvasSize)
            let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: draftEdits.rotation)
            let currentCropFrame = committedCropFrame(in: canvasSize, visibleImageSize: visibleImageSize)

            ZStack {
                ZStack(alignment: .bottom) {
                    Group {
                        if showsCroppingMode {
                            CroppingView(
                                image: image,
                                canvasSize: canvasSize,
                                edits: $draftEdits,
                                photoEditConfiguration: photoEditConfiguration
                            )
                        } else if hasAvailableAdjustments {
                            adjustCanvas(
                                geometrySize: canvasSize,
                                cropFrame: currentCropFrame
                            )
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(.snappy(duration: 0.25), value: selectedSection)
                    .animation(.snappy(duration: 0.25), value: selectedAdjustment)

                    if hasAvailableAdjustments {
                        ControlsView(
                            edits: $draftEdits,
                            cropConstraint: $draftEdits.cropConstraint,
                            photoEditConfiguration: photoEditConfiguration,
                            selectedAdjustment: $selectedAdjustment,
                            selectedSection: $selectedSection,
                            onSelectCropConstraint: { constraint in
                                applyCropConstraint(
                                    constraint,
                                    from: currentCropFrame,
                                    geometrySize: canvasSize,
                                    visibleImageSize: visibleImageSize
                                )
                            }
                        )
                        .zIndex(1)
                    }
                }
            }
            .onChange(of: selectedAdjustment) { _, newValue in
                Self.log("adjustment -> \(newValue.rawValue)")
                if newValue.section != selectedSection {
                    selectedSection = newValue.section
                }
            }
            .onChange(of: selectedSection) { _, newValue in
                Self.log("section -> \(newValue.rawValue)")
            }
            .onAppear {
                sanitizeSelection()
            }
        }
        .border(.yellow, width: photoEditConfiguration.showFrames ? 1 : 0)
    }

    @ViewBuilder
    func adjustCanvas(geometrySize: CGSize, cropFrame: CGRect) -> some View {
        let fittedSize = aspectFitSize(for: image.size, in: geometrySize)
        let baseScale = rotationFitScale(for: fittedSize, angle: draftEdits.rotation)
        let cropCenterOffset = CGSize(
            width: cropFrame.midX - (geometrySize.width / 2),
            height: cropFrame.midY - (geometrySize.height / 2)
        )
        let cropScaleX = cropFrame.width > 0 ? geometrySize.width / cropFrame.width : 1
        let cropScaleY = cropFrame.height > 0 ? geometrySize.height / cropFrame.height : 1
        let cropScale = min(cropScaleX, cropScaleY)
        let displayedCropSize = CGSize(
            width: cropFrame.width * cropScale,
            height: cropFrame.height * cropScale
        )

        ZStack {
            Color.black

            adjustPreviewImage(targetSize: geometrySize)
                .resizable()
                .scaledToFit()
                .scaleEffect(baseScale * cropScale)
                .rotationEffect(draftEdits.rotation)
                .offset(
                    x: -cropCenterOffset.width * cropScale,
                    y: -cropCenterOffset.height * cropScale
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask {
                    Rectangle()
                        .frame(width: displayedCropSize.width, height: displayedCropSize.height)
                        .position(x: geometrySize.width / 2, y: geometrySize.height / 2)
                }
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
        .clipped()
    }

}

// MARK: - Crop State

private extension PhotoEditor {
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

    func adjustPreviewImage(targetSize: CGSize) -> Image {
        if let adjustedImage = image.applyingColorAdjustments(using: draftEdits, targetSize: targetSize) {
            return Image(uiImage: adjustedImage)
        }

        return Image(uiImage: image)
    }

    func sanitizeSelection() {
        if !photoEditConfiguration.allowedAdjustments.contains(selectedAdjustment),
           let firstAdjustment = PhotoEditConfiguration.Adjustment.allCases.first(where: photoEditConfiguration.allowedAdjustments.contains) {
            selectedAdjustment = firstAdjustment
        }

        if selectedAdjustment.section != selectedSection {
            selectedSection = selectedAdjustment.section
        }
    }

    func committedCropFrame(in geometrySize: CGSize, visibleImageSize: CGSize) -> CGRect {
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

    func applyCropConstraint(
        _ constraint: CropConstraint,
        from cropFrame: CGRect,
        geometrySize: CGSize,
        visibleImageSize: CGSize
    ) {
        draftEdits.cropConstraint = constraint

        let updatedCropFrame: CGRect
        if let ratio = constraint.ratio {
            updatedCropFrame = CropFrameMutation.aspectRatioAdjustedCropFrame(cropFrame, ratio: ratio)
        } else {
            updatedCropFrame = cropFrame
        }

        let constrained = CropFrameMutation.constrainedCropFrame(
            updatedCropFrame,
            moving: .all,
            within: CGRect(origin: .zero, size: geometrySize),
            visibleImageSize: visibleImageSize,
            rotation: draftEdits.rotation,
            cropConstraint: constraint
        )

        draftEdits.crop = LosslessEditGeometry.normalizedCrop(
            from: CropFrameMutation.clamped(cropFrame: constrained.standardized, to: CGRect(origin: .zero, size: geometrySize)),
            in: geometrySize,
            visibleImageSize: visibleImageSize
        )
    }
}

// MARK: - Buttons

private extension PhotoEditor {
    var cancelButton: some View {
        CircularSymbolButton(systemName: Self.xmark) {
            Self.log("tapped cancel")
            sanitizeSelection()
            dismiss()
        }
        .accessibilityLabel("Cancel")
    }

    var acceptButton: some View {
        CircularSymbolButton(systemName: Self.checkmark) {
            Self.log("tapped accept")
            edits = draftEdits
            sanitizeSelection()
            save?()
            dismiss()
        }
        .accessibilityLabel("OK")
    }
}

// MARK: - Preview

#Preview {
    if let image = UIImage(systemName: "photo") {
        PhotoEditor(
            .constant(LosslessEdits(crop: nil, rotation: .zero)),
            image: image
        )
    }
}
