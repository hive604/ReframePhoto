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
        case contrast
        case saturation

        var id: String { rawValue }

        var title: String {
            switch self {
            case .tilt:
                return "Tilt"
            case .brightness:
                return "Brightness"
            case .contrast:
                return "Contrast"
            case .saturation:
                return "Saturation"
            }
        }

        var systemImage: String {
            switch self {
            case .tilt:
                return "rectangle.landscape.rotate"
            case .brightness:
                return "sun.max"
            case .contrast:
                return "circle.lefthalf.filled"
            case .saturation:
                return "drop"
            }
        }
    }

    let image: Image
    let sourceUIImage: UIImage?
    let imageSize: CGSize
    let geometrySize: CGSize
    @Binding var edits: LosslessEdits
    let cropFrame: CGRect

    @State private var selectedAdjustment: AdjustmentMode = .tilt

    @ScaledMetric private var valueWidth = 52
    @ScaledMetric(relativeTo: .caption2) private var panelWidth: CGFloat = 520
    @ScaledMetric(relativeTo: .caption2) private var rowSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var panelPadding: CGFloat = 12

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
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text("Adjust")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: rowSpacing) {
                adjustmentSlider(
                    title: "Tilt",
                    systemImage: "rectangle.landscape.rotate",
                    value: rotationBinding,
                    range: -15...15,
                    default: 0.0
                )
                adjustmentSlider(
                    title: "Brightness",
                    systemImage: "sun.max",
                    value: $edits.brightness,
                    range: -1...1,
                    default: 0.0
                )
                adjustmentSlider(
                    title: "Contrast",
                    systemImage: "circle.lefthalf.filled",
                    value: $edits.contrast,
                    range: 0...2,
                    default: 1.0
                )
                adjustmentSlider(
                    title: "Saturation",
                    systemImage: "drop",
                    value: $edits.saturation,
                    range: 0...2,
                    default: 1.0
                )
            }
        }
    }

    private var compactControlsPanel: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Picker("Adjustment", selection: $selectedAdjustment) {
                ForEach(AdjustmentMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            activeCompactSlider
        }
    }

    @ViewBuilder
    private var activeCompactSlider: some View {
        switch selectedAdjustment {
        case .tilt:
            adjustmentSlider(
                title: AdjustmentMode.tilt.title,
                systemImage: AdjustmentMode.tilt.systemImage,
                value: rotationBinding,
                range: -15...15,
                default: 0.0
            )
        case .brightness:
            adjustmentSlider(
                title: AdjustmentMode.brightness.title,
                systemImage: AdjustmentMode.brightness.systemImage,
                value: $edits.brightness,
                range: -1...1,
                default: 0.0
            )
        case .contrast:
            adjustmentSlider(
                title: AdjustmentMode.contrast.title,
                systemImage: AdjustmentMode.contrast.systemImage,
                value: $edits.contrast,
                range: 0...2,
                default: 1.0
            )
        case .saturation:
            adjustmentSlider(
                title: AdjustmentMode.saturation.title,
                systemImage: AdjustmentMode.saturation.systemImage,
                value: $edits.saturation,
                range: 0...2,
                default: 1.0
            )
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
                .foregroundStyle(.secondary)
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
