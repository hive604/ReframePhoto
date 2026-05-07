//
//  ControlsView.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-24.
//

import SwiftUI

enum AdjustmentSection: String, CaseIterable, Identifiable {
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

extension PhotoEditConfiguration.Adjustment {
    var title: String {
        switch self {
        case .crop:
            return "Crop"
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
        case .crop:
            return "crop"
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

    var section: AdjustmentSection {
        switch self {
        case .crop, .tilt:
            return .geometry
        case .brightness, .exposure, .contrast, .sharpness:
            return .tone
        case .saturation, .vibrance:
            return .color
        case .warmth, .tint:
            return .whiteBalance
        }
    }

    var displayRange: ClosedRange<Double> {
        switch self {
        case .crop:
            return 0...1
        case .tilt:
            return -15...15
        case .brightness, .exposure, .vibrance, .warmth, .tint:
            return -1...1
        case .contrast, .saturation, .sharpness:
            return 0...2
        }
    }

    var defaultValue: Double {
        switch self {
        case .crop:
            return 0.0
        case .tilt, .brightness, .exposure, .vibrance, .sharpness, .warmth, .tint:
            return 0.0
        case .contrast, .saturation:
            return 1.0
        }
    }

    var isSliderAdjustment: Bool {
        self != .crop
    }
}

struct ControlsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var edits: LosslessEdits
    @Binding var cropConstraint: CropConstraint
    let photoEditConfiguration: PhotoEditConfiguration
    @Binding var selectedAdjustment: PhotoEditConfiguration.Adjustment
    @Binding var selectedSection: AdjustmentSection
    let onSelectCropConstraint: (CropConstraint) -> Void
    let onRotate: (RotationDirection) -> Void

    @ScaledMetric private var valueWidth = 52
    @ScaledMetric(relativeTo: .caption2) private var panelWidth: CGFloat = 520
    @ScaledMetric(relativeTo: .caption2) private var rowSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var panelPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var sectionSpacing: CGFloat = 16
    @State private var isShowingCropConstraintPopover = false

    private var availableTools: [PhotoEditConfiguration.Adjustment] {
        let allowedAdjustments = photoEditConfiguration.allowedAdjustments
        return PhotoEditConfiguration.Adjustment.allCases.filter(allowedAdjustments.contains)
    }

    private var availableAdjustments: [PhotoEditConfiguration.Adjustment] {
        availableTools.filter(\.isSliderAdjustment)
    }

    private var availableSections: [AdjustmentSection] {
        AdjustmentSection.allCases.filter { section in
            availableTools.contains(where: { $0.section == section })
        }
    }

    var body: some View {
        controlsPanel
            .onAppear { sanitizeSelection() }
            .onChange(of: availableTools.map(\.rawValue)) { _, _ in sanitizeSelection() }
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { edits.rotation.degrees },
            set: { edits.rotation = .degrees($0) }
        )
    }

    private var controlsPanel: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactControlsPanel
            } else {
                regularControlsPanel
            }
        }
        .padding(panelPadding)
        .frame(maxWidth: panelWidth)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
        .padding()
    }

    private var regularControlsPanel: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: 8) {
                ForEach(availableSections) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedSection = section
                            if selectedAdjustment.section != section,
                               let first = tool(for: section) {
                                selectedAdjustment = first
                            }
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

            adjustmentSection {
                sectionControls(for: selectedSection)
            }
        }
        .animation(.snappy(duration: 0.25), value: selectedSection)
    }

    private var compactControlsPanel: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableTools) { adjustment in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedAdjustment = adjustment
                                selectedSection = adjustment.section
                            }
                        } label: {
                            Label(adjustment.title, systemImage: adjustment.systemImage)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedAdjustment == adjustment ? .white.opacity(0.18) : .white.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            activeCompactControl
        }
    }

    @ViewBuilder
    private var activeCompactControl: some View {
        if selectedAdjustment == .crop {
            aspectRatioRow
        } else if selectedAdjustment == .tilt {
            VStack(alignment: .leading, spacing: rowSpacing) {
                adjustmentSlider(for: .tilt)
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { onRotate(.counterClockwise) }
                    } label: {
                        Label("Rotate Left", systemImage: "rotate.left")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) { onRotate(.clockwise) }
                    } label: {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        } else if availableAdjustments.contains(selectedAdjustment) {
            adjustmentSlider(for: selectedAdjustment)
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
    private func sectionControls(for section: AdjustmentSection) -> some View {
        if section == .geometry, photoEditConfiguration.allowedAdjustments.contains(.crop) {
            aspectRatioRow
        }

        ForEach(adjustments(for: section)) { adjustment in
            adjustmentSlider(for: adjustment)
        }
    }

    private var aspectRatioRow: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    selectedAdjustment = .crop
                    selectedSection = .geometry
                }
            } label: {
                HStack {
                    Label("Aspect Ratio", systemImage: "aspectratio")
                        .labelStyle(
                            AdaptiveToolbarLabelStyle(showsTitle: true)
                        )
                    if selectedAdjustment == .crop {
                        Button {
                            isShowingCropConstraintPopover = true
                        } label: {
                            Label(cropConstraint.label, systemImage: "aspectratio")
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $isShowingCropConstraintPopover, arrowEdge: .bottom) {
                            cropConstraintPopover
                                .colorScheme(.dark)
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if horizontalSizeClass == .regular {
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { onRotate(.counterClockwise) }
                    } label: {
                        Label("Rotate Left", systemImage: "rotate.left")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) { onRotate(.clockwise) }
                    } label: {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var cropConstraintPopover: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(CropConstraint.displayOrder, id: \.self) { constraint in
                Button {
                    onSelectCropConstraint(constraint)
                    isShowingCropConstraintPopover = false
                } label: {
                    HStack {
                        Text(constraint.label)
                            .font(.callout.weight(.medium))
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
        .colorScheme(.dark)
    }

    @ViewBuilder
    private func adjustmentSlider(for adjustment: PhotoEditConfiguration.Adjustment) -> some View {
        adjustmentSlider(
            title: adjustment.title,
            systemImage: adjustment.systemImage,
            value: binding(for: adjustment),
            range: adjustment.displayRange,
            default: adjustment.defaultValue
        )
    }

    private func binding(for adjustment: PhotoEditConfiguration.Adjustment) -> Binding<Double> {
        switch adjustment {
        case .crop:
            return .constant(0)
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

    private func adjustments(for section: AdjustmentSection) -> [PhotoEditConfiguration.Adjustment] {
        availableAdjustments.filter { $0.section == section }
    }

    private func tool(for section: AdjustmentSection) -> PhotoEditConfiguration.Adjustment? {
        availableTools.first(where: { $0.section == section })
    }

    private func sanitizeSelection() {
        if !availableTools.contains(selectedAdjustment),
           let firstAdjustment = availableTools.first {
            selectedAdjustment = firstAdjustment
        }

        if !availableSections.contains(selectedSection) {
            selectedSection = selectedAdjustment.section
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
}
