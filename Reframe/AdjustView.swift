//
//  AdjustView.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-24.
//

import SwiftUI

struct AdjustView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum AdjustmentMode: String, CaseIterable, Identifiable {
        case tilt
        case brightness
        case exposure
        case contrast
        case saturation
        case vibrance
        case sharpness
        case warmth
        case tint

        var id: String { rawValue }

        init(_ adjustment: PhotoEditConfiguration.Adjustment) {
            switch adjustment {
            case .crop:
                self = .tilt
            case .tilt:
                self = .tilt
            case .brightness:
                self = .brightness
            case .exposure:
                self = .exposure
            case .contrast:
                self = .contrast
            case .saturation:
                self = .saturation
            case .vibrance:
                self = .vibrance
            case .sharpness:
                self = .sharpness
            case .warmth:
                self = .warmth
            case .tint:
                self = .tint
            }
        }

        var title: String {
            switch self {
            case .tilt:
                return "Tilt"
            case .brightness:
                return "Brightness"
            case .exposure:
                return "Exposure"
            case .contrast:
                return "Contrast"
            case .saturation:
                return "Saturation"
            case .vibrance:
                return "Vibrance"
            case .sharpness:
                return "Sharpness"
            case .warmth:
                return "Warmth"
            case .tint:
                return "Tint"
            }
        }

        var systemImage: String {
            switch self {
            case .tilt:
                return "rectangle.landscape.rotate"
            case .brightness:
                return "sun.max"
            case .exposure:
                return "plusminus.circle"
            case .contrast:
                return "circle.lefthalf.filled"
            case .saturation:
                return "drop"
            case .vibrance:
                return "paintbrush"
            case .sharpness:
                return "righttriangle.fill"
            case .warmth:
                return "thermometer.variable"
            case .tint:
                return "drop.halffull"
            }
        }

        var displayRange: ClosedRange<Double> {
            switch self {
            case .tilt:
                return -15...15
            case .brightness, .exposure, .vibrance, .warmth, .tint:
                return -1...1
            case .contrast, .saturation:
                return 0...2
            case .sharpness:
                return 0...2
            }
        }

        var defaultValue: Double {
            switch self {
            case .tilt, .brightness, .exposure, .vibrance, .sharpness, .warmth, .tint:
                return 0.0
            case .contrast, .saturation:
                return 1.0
            }
        }
    }

    private enum AdjustmentSection: String, CaseIterable, Identifiable {
        case geometry
        case tone
        case color
        case whiteBalance

        var id: String { rawValue }

        var title: String {
            switch self {
            case .geometry:
                return "Geometry"
            case .tone:
                return "Tone"
            case .color:
                return "Color"
            case .whiteBalance:
                return "White Balance"
            }
        }
    }

    let image: Image
    let sourceUIImage: UIImage?
    let imageSize: CGSize
    let geometrySize: CGSize
    @Binding var edits: LosslessEdits
    let cropFrame: CGRect
    let allowedAdjustments: Set<PhotoEditConfiguration.Adjustment>

    @State private var selectedAdjustment: AdjustmentMode = .tilt
    @State private var selectedSection: AdjustmentSection = .tone

    @ScaledMetric private var valueWidth = 52
    @ScaledMetric(relativeTo: .caption2) private var panelWidth: CGFloat = 520
    @ScaledMetric(relativeTo: .caption2) private var rowSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var panelPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var sectionSpacing: CGFloat = 16

    private var availableAdjustments: [AdjustmentMode] {
        AdjustmentMode.allCases.filter { mode in
            allowedAdjustments.contains(PhotoEditConfiguration.Adjustment(rawValue: mode.rawValue)!)
        }
    }

    private var availableSections: [AdjustmentSection] {
        AdjustmentSection.allCases.filter { !adjustments(for: $0).isEmpty }
    }

    var body: some View {
        let fittedSize = aspectFitSize(for: imageSize, in: geometrySize)
        let baseScale = rotationFitScale(for: fittedSize, angle: edits.rotation)
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

        ZStack(alignment: .bottom) {
            ZStack {
                Color.black

                previewImage
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(baseScale * cropScale)
                    .rotationEffect(edits.rotation)
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

            controlsPanel
            .padding(panelPadding)
            .frame(maxWidth: panelWidth)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
            .padding()
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
        .onAppear {
            sanitizeSelection()
        }
        .onChange(of: availableAdjustments.map(\.rawValue)) { _, _ in
            sanitizeSelection()
        }
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { edits.rotation.degrees },
            set: { edits.rotation = .degrees($0) }
        )
    }

    @ViewBuilder
    private var controlsPanel: some View {
        if horizontalSizeClass == .compact {
            compactControlsPanel
        } else {
            regularControlsPanel
        }
    }

    private var regularControlsPanel: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: 8) {
                ForEach(availableSections) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedSection = section
                        }
                    } label: {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                selectedSection == section ? .white.opacity(0.18) : .white.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            activeRegularSection
        }
        .animation(.snappy(duration: 0.25), value: selectedSection)
    }

    private var compactControlsPanel: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableAdjustments) { mode in
                        Button {
                            selectedAdjustment = mode
                        } label: {
                            Label(mode.title, systemImage: mode.systemImage)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedAdjustment == mode ? .white.opacity(0.18) : .white.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            activeCompactSlider
        }
    }

    @ViewBuilder
    private var activeCompactSlider: some View {
        if availableAdjustments.contains(selectedAdjustment) {
            adjustmentSlider(for: selectedAdjustment)
        }
    }

    @ViewBuilder
    private var activeRegularSection: some View {
        switch selectedSection {
        case .geometry:
            adjustmentSection {
                sectionSliders(for: .geometry)
            }
        case .tone:
            adjustmentSection {
                sectionSliders(for: .tone)
            }
        case .color:
            adjustmentSection {
                sectionSliders(for: .color)
            }
        case .whiteBalance:
            adjustmentSection {
                sectionSliders(for: .whiteBalance)
            }
        }
    }

    @ViewBuilder
    private func adjustmentSection(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func sectionSliders(for section: AdjustmentSection) -> some View {
        ForEach(adjustments(for: section)) { mode in
            adjustmentSlider(for: mode)
        }
    }

    @ViewBuilder
    private func adjustmentSlider(for mode: AdjustmentMode) -> some View {
        adjustmentSlider(
            title: mode.title,
            systemImage: mode.systemImage,
            value: binding(for: mode),
            range: mode.displayRange,
            default: mode.defaultValue
        )
    }

    private func binding(for mode: AdjustmentMode) -> Binding<Double> {
        switch mode {
        case .tilt:
            return rotationBinding
        case .brightness:
            return $edits.brightness
        case .exposure:
            return $edits.exposure
        case .contrast:
            return $edits.contrast
        case .saturation:
            return $edits.saturation
        case .vibrance:
            return $edits.vibrance
        case .sharpness:
            return $edits.sharpness
        case .warmth:
            return $edits.warmth
        case .tint:
            return $edits.tint
        }
    }

    private func adjustments(for section: AdjustmentSection) -> [AdjustmentMode] {
        availableAdjustments.filter { mode in
            switch section {
            case .geometry:
                return mode == .tilt
            case .tone:
                return mode == .brightness || mode == .exposure || mode == .contrast || mode == .sharpness
            case .color:
                return mode == .saturation || mode == .vibrance
            case .whiteBalance:
                return mode == .warmth || mode == .tint
            }
        }
    }

    private func sanitizeSelection() {
        if let firstAdjustment = availableAdjustments.first,
           !availableAdjustments.contains(selectedAdjustment) {
            selectedAdjustment = firstAdjustment
        }

        if let firstSection = availableSections.first,
           !availableSections.contains(selectedSection) {
            selectedSection = firstSection
        }
    }

    @ViewBuilder
    private func adjustmentSlider(
        title: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        default defaultValue: Double?
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .labelStyle(
                    AdaptiveToolbarLabelStyle(showsTitle: horizontalSizeClass == .regular)
                )
                .frame(alignment: .leading)
            Slider(value: value, in: range)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(width: valueWidth, alignment: .trailing)
            let canReset = if let defaultValue, abs(defaultValue - value.wrappedValue) > 0.05 { true } else { false }
            CircularSymbolButton(systemName: "arrow.uturn.backward.circle.fill") {
                if let defaultValue {
                    value.wrappedValue = defaultValue
                }
            }
            .opacity(canReset ? 1.0 : 0.0)
        }
        .font(.caption2)
    }

    private func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
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

    private func rotationFitScale(for size: CGSize, angle: Angle) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        let rotatedSize = rotatedBoundingSize(for: size, angle: angle)
        guard rotatedSize.width > 0, rotatedSize.height > 0 else { return 1 }

        let horizontalScale = size.width / rotatedSize.width
        let verticalScale = size.height / rotatedSize.height

        return min(horizontalScale, verticalScale, 1)
    }

    private func rotatedBoundingSize(for size: CGSize, angle: Angle) -> CGSize {
        let radians = angle.radians
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))

        return CGSize(
            width: size.width * absoluteCosine + size.height * absoluteSine,
            height: size.width * absoluteSine + size.height * absoluteCosine
        )
    }

    private var previewImage: Image {
        if let sourceUIImage,
           let adjustedImage = sourceUIImage.applyingColorAdjustments(using: edits, targetSize: geometrySize) {
            return Image(uiImage: adjustedImage)
        }

        return image
    }
}
