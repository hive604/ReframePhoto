//
//  ReframePhotoEditor.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI

struct ReframePhotoEditor: View {
    static let checkmark = "checkmark.circle.fill"
    static let xmark = "xmark.circle.fill"

    let image: Image
    @Binding var edits: LosslessEdits
    let onCancel: (() -> Void)?
    let onConfirm: (() -> Void)?

    @State private var draftEdits: LosslessEdits
    @State private var tool: ToolMode = .tilt

    private enum ToolMode: String, CaseIterable, Identifiable {
        case tilt
        case crop

        var id: String { rawValue }
    }

    init(
        image: Image,
        edits: Binding<LosslessEdits>,
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self.image = image
        _edits = edits
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftEdits = State(initialValue: edits.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editorImage

            if tool == .tilt {
                tiltControls
            }
        }
        .background(Color.black)
        .onChange(of: edits) { _, newValue in
            draftEdits = newValue
            tool = .tilt
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Content

private extension ReframePhotoEditor {
    var editorImage: some View {
        GeometryReader { geometry in
            image
                .resizable()
                .scaledToFit()
                .scaleEffect(rotationFitScale(for: geometry.size, angle: draftEdits.rotation))
                .rotationEffect(draftEdits.rotation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var tiltControls: some View {
        VStack(spacing: 8) {
            Slider(
                value: rotationDegreesBinding,
                in: -15 ... 15,
                step: 0.1
            ) {
                Text("Tilt")
            } minimumValueLabel: {
                Text("-15°").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("15°").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 320)
            .tint(.white)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Controls

private extension ReframePhotoEditor {

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
            set: { draftEdits.rotation = .degrees($0) }
        )
    }

    var cancelButton: some View {
        circularSymbolButton(
            systemName: Self.xmark,
            accessibilityLabel: "Cancel"
        ) {
            draftEdits = edits
            tool = .tilt
            onCancel?()
        }
    }

    var acceptButton: some View {
        circularSymbolButton(
            systemName: Self.checkmark,
            accessibilityLabel: "OK"
        ) {
            edits = draftEdits
            tool = .tilt
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
        edits: .constant(LosslessEdits(crop: .zero, rotation: .zero))
    )
}
