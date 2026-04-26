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

    let photoEditConfiguration: PhotoEditConfiguration

    private enum ToolMode: String, CaseIterable, Identifiable {
        case crop
        case adjust

        var id: String { rawValue }
    }

    private var cropIsAllowed: Bool {
        photoEditConfiguration.allowedAdjustments.contains(.crop)
    }

    private var hasAvailableAdjustments: Bool {
        !photoEditConfiguration.allowedAdjustments.subtracting([.crop]).isEmpty
    }

    private var availableTools: [ToolMode] {
        var tools: [ToolMode] = []

        if cropIsAllowed {
            tools.append(.crop)
        }

        if hasAvailableAdjustments {
            tools.append(.adjust)
        }

        return tools
    }

    public init(
        uiImage: UIImage,
        edits: Binding<LosslessEdits>,
        photoEditConfiguration: PhotoEditConfiguration = PhotoEditConfiguration(),
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        image = Image(uiImage: uiImage)
        sourceUIImage = uiImage
        imageSize = uiImage.size
        _edits = edits
        self.photoEditConfiguration = photoEditConfiguration
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftEdits = State(initialValue: edits.wrappedValue)
        _tool = State(initialValue: photoEditConfiguration.allowedAdjustments.contains(.crop) ? .crop : .adjust)
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

            if availableTools.count > 1 {
                Picker("Tool", selection: $tool) {
                    ForEach(availableTools) { tool in
                        Text(tool.rawValue.capitalized).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

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
            let currentCropFrame = committedCropFrame(in: geometry.size, visibleImageSize: visibleImageSize)

            ZStack {
                if tool == .crop, cropIsAllowed {
                    CroppingView(
                        image: image,
                        sourceUIImage: sourceUIImage,
                        imageSize: imageSize,
                        geometrySize: geometry.size,
                        edits: $draftEdits,
                        cropConstraint: $draftEdits.cropConstraint,
                        croppingEffects: photoEditConfiguration.croppingEffects
                    )
                } else if hasAvailableAdjustments {
                    AdjustView(
                        image: image,
                        sourceUIImage: sourceUIImage,
                        imageSize: imageSize,
                        geometrySize: geometry.size,
                        edits: $draftEdits,
                        cropFrame: currentCropFrame,
                        allowedAdjustments: photoEditConfiguration.allowedAdjustments
                    )
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            .onChange(of: tool) { _, newValue in
                Self.log("tool -> \(newValue)")
            }
            .onAppear {
                if !availableTools.contains(tool), let firstTool = availableTools.first {
                    tool = firstTool
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
}

// MARK: - Buttons

private extension PhotoEditor {
    var cancelButton: some View {
        CircularSymbolButton(systemName: Self.xmark) {
            Self.log("tapped cancel")
            draftEdits = edits
            tool = availableTools.first ?? .adjust
            onCancel?()
        }
        .accessibilityLabel("Cancel")
    }

    var acceptButton: some View {
        CircularSymbolButton(systemName: Self.checkmark) {
            Self.log("tapped accept")
            edits = draftEdits
            tool = availableTools.first ?? .adjust
            onConfirm?()
        }
        .accessibilityLabel("OK")
    }
}

// MARK: - Preview

#Preview {
    if let image = UIImage(systemName: "photo") {
        PhotoEditor(
            uiImage: image,
            edits: .constant(LosslessEdits(crop: nil, rotation: .zero))
        )
    }
}
