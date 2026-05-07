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
    private static let minimumStoredCropDimension: CGFloat = 0.0001

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
            let displayGeometry = displayGeometry(in: canvasSize)
            let currentCropFrame = committedCropFrame(in: canvasSize, visibleImageSize: displayGeometry.visibleImageSize)

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
                            edits: controlsEdits,
                            cropConstraint: $draftEdits.cropConstraint,
                            photoEditConfiguration: photoEditConfiguration,
                            selectedAdjustment: $selectedAdjustment,
                            selectedSection: $selectedSection,
                            onSelectCropConstraint: { constraint in
                                applyAspectRatioConstraint(
                                    constraint,
                                    to: currentCropFrame,
                                    inCanvas: canvasSize,
                                    displaySize: displayGeometry.visibleImageSize
                                )
                            },
                            onRotate: { direction in
                                withAnimation(.snappy(duration: 0.25)) {
                                    rotateByQuarterTurn(direction: direction, in: canvasSize)
                                }
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
        let displayGeometry = displayGeometry(in: geometrySize)
        let fittedSize = displayGeometry.fittedSize
        let renderSize = displayGeometry.renderSize
        let baseScale = LosslessEditGeometry.rotationFitScale(for: fittedSize, angle: displayGeometry.tiltRotation)
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
            let _ = {
                Self.log("baseScale=\(baseScale), cropScale=\(cropScale), total=\(baseScale * cropScale)")
            }()
            Color.black

            adjustPreviewImage(targetSize: geometrySize)
                .resizable()
                .scaledToFit()
                .frame(width: renderSize.width, height: renderSize.height)
                .scaleEffect(baseScale)
                .rotationEffect(draftEdits.rotation)
                .offset(
                    x: -cropCenterOffset.width,
                    y: -cropCenterOffset.height
                )
                .scaleEffect(cropScale)
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

    var controlsEdits: Binding<LosslessEdits> {
        Binding(
            get: {
                var controlEdits = draftEdits
                controlEdits.rotation = draftEdits.rotation - draftEdits.rotation.nearestQuarterTurn
                return controlEdits
            },
            set: { newValue in
                let layoutRotation = draftEdits.rotation.nearestQuarterTurn
                let incomingTiltRotation = newValue.rotation - newValue.rotation.nearestQuarterTurn

                var updatedEdits = newValue
                updatedEdits.rotation = layoutRotation + incomingTiltRotation
                draftEdits = updatedEdits
            }
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
           crop.width > Self.minimumStoredCropDimension,
           crop.height > Self.minimumStoredCropDimension {
            return LosslessEditGeometry.croppedFrame(
                from: crop,
                in: geometrySize,
                visibleImageSize: visibleImageSize
            )
        }

        let displayGeometry = displayGeometry(in: geometrySize)
        return LosslessEditGeometry.uncroppedFrame(
            in: geometrySize,
            visibleImageSize: visibleImageSize,
            rotation: displayGeometry.tiltRotation
        )
    }

    func applyAspectRatioConstraint(
        _ constraint: CropConstraint,
        to cropFrame: CGRect,
        inCanvas geometrySize: CGSize,
        displaySize visibleImageSize: CGSize
    ) {
        draftEdits.cropConstraint = constraint

        let displayGeometry = displayGeometry(in: geometrySize)

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
            rotation: displayGeometry.tiltRotation,
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

// MARK: - Rotation Helpers
private extension PhotoEditor {
    func rotateByQuarterTurn(direction: RotationDirection, in canvasSize: CGSize) {
        let hasStoredCrop = draftEdits.crop?.standardized.width ?? 0 > Self.minimumStoredCropDimension
            && draftEdits.crop?.standardized.height ?? 0 > Self.minimumStoredCropDimension

        guard hasStoredCrop, let crop = draftEdits.crop?.standardized else {
            draftEdits.rotation = .degrees(draftEdits.rotation.degrees + Double(direction.rawValue * 90))
            draftEdits.crop = nil
            return
        }

        let currentDisplaySize = displayGeometry(in: canvasSize).visibleImageSize
        let currentCanvasCrop = LosslessEditGeometry.croppedFrame(
            from: crop,
            in: canvasSize,
            visibleImageSize: currentDisplaySize
        )

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let rotatedCanvasCrop = rotateAxisAlignedRect90(currentCanvasCrop, around: center, direction: direction)

        draftEdits.rotation = .degrees(draftEdits.rotation.degrees + Double(direction.rawValue * 90))

        let newDisplayGeometry = displayGeometry(in: canvasSize)
        let newDisplaySize = newDisplayGeometry.visibleImageSize
        let bounds = CropBounds(
            in: CGRect(origin: .zero, size: canvasSize),
            visibleImageSize: newDisplaySize,
            rotation: newDisplayGeometry.tiltRotation
        )
        let clamped = bounds.clamped(rotatedCanvasCrop)

        draftEdits.crop = LosslessEditGeometry.normalizedCrop(
            from: clamped,
            in: canvasSize,
            visibleImageSize: newDisplaySize
        )
    }

    /// Rotates an axis-aligned rect by ±90° around a center, returning an axis-aligned rect.
    func rotateAxisAlignedRect90(_ rect: CGRect, around center: CGPoint, direction: RotationDirection) -> CGRect {
        // Translate rect center relative to canvas center
        let dx = rect.midX - center.x
        let dy = rect.midY - center.y

        // Rotate center by ±90°: +90° -> (-y, x), -90° -> (y, -x)
        let rotatedCenter: CGPoint = direction.rawValue > 0
            ? CGPoint(x: center.x - dy, y: center.y + dx)
            : CGPoint(x: center.x + dy, y: center.y - dx)

        // Swap width/height for 90° rotations
        let newSize = CGSize(width: rect.height, height: rect.width)

        return CGRect(
            x: rotatedCenter.x - newSize.width / 2,
            y: rotatedCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        ).standardized
    }
}

// MARK: - Display Geometry Helpers

private extension PhotoEditor {
    struct DisplayGeometry {
        let layoutRotation: Angle
        let tiltRotation: Angle
        let fittedSize: CGSize
        let visibleImageSize: CGSize

        var renderSize: CGSize {
            fittedSize.rotatedForLayout(by: -layoutRotation)
        }
    }

    func displayGeometry(in canvasSize: CGSize, rotation: Angle? = nil) -> DisplayGeometry {
        let rotation = rotation ?? draftEdits.rotation
        let layoutRotation = rotation.nearestQuarterTurn
        let tiltRotation = rotation - layoutRotation
        let layoutImageSize = image.size.rotatedForLayout(by: layoutRotation)
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: layoutImageSize, in: canvasSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: tiltRotation)

        return DisplayGeometry(
            layoutRotation: layoutRotation,
            tiltRotation: tiltRotation,
            fittedSize: fittedSize,
            visibleImageSize: visibleImageSize
        )
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

private extension CGSize {
    func rotatedForLayout(by angle: Angle) -> CGSize {
        switch angle.normalizedQuarterTurns {
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
