//
//  ContentView.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import PhotosUI
import Reframe

private struct SavedEditorSettings: Codable {
    var losslessEdits: LosslessEdits
    var allowedAdjustmentRawValues: [String]
    var dimEnabled: Bool
    var dimOpacity: Double
    var blurEnabled: Bool
    var blurRadius: Double
    var desaturateEnabled: Bool
    var desaturateAmount: Double
}

struct ContentView: View {
    private enum OptionsPanel: String, CaseIterable, Identifiable {
        case crop
        case adjustments

        var id: String { rawValue }

        var title: String { rawValue.capitalized }
    }

    // Store only a lightweight reference (filename) in UserDefaults
    @AppStorage("selectedImageUUIDString") private var selectedImageUUIDString: String?

    // In-memory image for display
    @State private var displayedImage: UIImage?

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
    @State private var isShowingEditor = false
    @State private var selectedPanel: OptionsPanel = .crop
    @State private var enabledAdjustments = Set(PhotoEditConfiguration.Adjustment.allCases)

    // Cropping effects state
    @State private var croppingEffects: CroppingEffectSet = []
    @State private var dimEnabled: Bool = false
    @State private var dimOpacity: Double = 0.45
    @State private var blurEnabled: Bool = false
    @State private var blurRadius: Double = 8
    @State private var desaturateEnabled: Bool = false
    @State private var desaturateAmount: Double = 1

    private var cropEnabled: Binding<Bool> {
        Binding(
            get: { enabledAdjustments.contains(.crop) },
            set: { isEnabled in
                if isEnabled {
                    enabledAdjustments.insert(.crop)
                } else {
                    enabledAdjustments.remove(.crop)
                }
            }
        )
    }

    private var configurableAdjustments: [PhotoEditConfiguration.Adjustment] {
        PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop }
    }

    fileprivate func clearImage() {
        withAnimation {
            deleteImage()
            losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
            displayedImage = nil
            selectedImageUUIDString = nil

            enabledAdjustments = Set(PhotoEditConfiguration.Adjustment.allCases)
            croppingEffects = []
            dimEnabled = false; dimOpacity = 0.45
            blurEnabled = false; blurRadius = 8
            desaturateEnabled = false; desaturateAmount = 1
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let uiImage = displayedImage,
                       let rendered = uiImage.applying(losslessEdits, outputSize: uiImage.size) {
                        Image(uiImage:rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.secondary, lineWidth: 1)
                            )
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "No Image Selected",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Pick a photo from your library to begin.")
                        )
                        .padding(.horizontal)
                    }
                }

                GroupBox("Editor Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Options Panel", selection: $selectedPanel) {
                            ForEach(OptionsPanel.allCases) { panel in
                                Text(panel.title).tag(panel)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedPanel == .crop {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Enable Crop Tool", isOn: cropEnabled)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $dimEnabled) {
                                        HStack {
                                            Text("Dim")
                                            Spacer()
                                            Slider(value: $dimOpacity, in: 0...1) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!dimEnabled)
                                        }
                                    }

                                    Toggle(isOn: $blurEnabled) {
                                        HStack {
                                            Text("Blur")
                                            Spacer()
                                            Slider(value: $blurRadius, in: 0...20) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!blurEnabled)
                                        }
                                    }

                                    Toggle(isOn: $desaturateEnabled) {
                                        HStack {
                                            Text("Desaturate")
                                            Spacer()
                                            Slider(value: $desaturateAmount, in: 0...1) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!desaturateEnabled)
                                        }
                                    }
                                }
                                .disabled(!cropEnabled.wrappedValue)
                                .opacity(cropEnabled.wrappedValue ? 1 : 0.45)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Button("All On") {
                                        enabledAdjustments.formUnion(configurableAdjustments)
                                    }
                                    .buttonStyle(.bordered)

                                    Button("All Off") {
                                        enabledAdjustments.subtract(configurableAdjustments)
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()
                                }

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 12, alignment: .leading),
                                        GridItem(.flexible(), spacing: 12, alignment: .leading)
                                    ],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(configurableAdjustments) { adjustment in
                                        Toggle(
                                            adjustment.displayTitle,
                                            isOn: adjustmentBinding(for: adjustment)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity, alignment: .center)
                .onChange(of: enabledAdjustments) { _, _ in
                    persistEditorSettings()
                }
                .onChange(of: dimEnabled) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }
                .onChange(of: dimOpacity) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }
                .onChange(of: blurEnabled) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }
                .onChange(of: blurRadius) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }
                .onChange(of: desaturateEnabled) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }
                .onChange(of: desaturateAmount) { _, _ in
                    rebuildEffects()
                    persistEditorSettings()
                }

                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                        Label("Pick…", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isShowingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(displayedImage == nil)

                    Button(role: .destructive) {
                        clearImage()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(displayedImage == nil)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Photo Picker")
            .task { loadImage() }
            .fullScreenCover(isPresented: $isShowingEditor) {
                if let uiImage = displayedImage {
                    let config = PhotoEditConfiguration(
                        croppingEffects: croppingEffects,
                        allowedAdjustments: enabledAdjustments
                        )
                    Reframe.PhotoEditor(
                        uiImage: uiImage,
                        edits: $losslessEdits,
                        photoEditConfiguration: config
                        )
                    }
            }
        }
        .task(id: photoItem) {
             guard let item = photoItem else { return }
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    selectedImageUUIDString = UUID().uuidString
                    try saveImage(data)
                    displayedImage = UIImage(data: data)
                }
            } catch {
                print("Failed to load/persist image: \(error)")
            }
        }
    }
}

// MARK: - Persistence Helpers
private extension ContentView {
    func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var imageURL: URL? {
        selectedImageUUIDString != nil ? documentsDirectory().appendingPathComponent("selected_\(selectedImageUUIDString!)") : nil
    }

    private var settingsURL: URL? {
        selectedImageUUIDString != nil ? documentsDirectory().appendingPathComponent("settings_\(selectedImageUUIDString!)") : nil
    }

    func saveImage(_ data: Data) throws {
        // Store the original bytes as-is with a neutral filename (no extension)
        try data.write(to: imageURL!, options: .atomic)
    }

    func persistEditorSettings() {
        guard let settingsURL else { return }

        let settings = SavedEditorSettings(
            losslessEdits: losslessEdits,
            allowedAdjustmentRawValues: enabledAdjustments.map(\.rawValue).sorted(),
            dimEnabled: dimEnabled,
            dimOpacity: dimOpacity,
            blurEnabled: blurEnabled,
            blurRadius: blurRadius,
            desaturateEnabled: desaturateEnabled,
            desaturateAmount: desaturateAmount
        )

        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to persist settings: \(error)")
        }
    }

    func loadImage() {
        if let imageURL, let data = try? Data(contentsOf: imageURL), let image = UIImage(data: data) {
            displayedImage = image
        } else {
            clearImage()
        }

        if let settingsURL, let data = try? Data(contentsOf: settingsURL) {
            if let decoded = try? JSONDecoder().decode(SavedEditorSettings.self, from: data) {
                losslessEdits = decoded.losslessEdits
                enabledAdjustments = Set(
                    decoded.allowedAdjustmentRawValues.compactMap(PhotoEditConfiguration.Adjustment.init(rawValue:))
                )
                dimEnabled = decoded.dimEnabled
                dimOpacity = decoded.dimOpacity
                blurEnabled = decoded.blurEnabled
                blurRadius = decoded.blurRadius
                desaturateEnabled = decoded.desaturateEnabled
                desaturateAmount = decoded.desaturateAmount
                rebuildEffects()
            }
        }
    }

    func deleteImage() {
        if let imageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        if let settingsURL {
            try? FileManager.default.removeItem(at: settingsURL)
        }
        selectedImageUUIDString = nil
    }

    func rebuildEffects() {
        var set: CroppingEffectSet = []
        if dimEnabled { set.insert(.dim(dimOpacity)) }
        if blurEnabled { set.insert(.blur(blurRadius)) }
        if desaturateEnabled { set.insert(.desaturate(desaturateAmount)) }
        croppingEffects = set
    }

    func adjustmentBinding(for adjustment: PhotoEditConfiguration.Adjustment) -> Binding<Bool> {
        Binding(
            get: { enabledAdjustments.contains(adjustment) },
            set: { isEnabled in
                if isEnabled {
                    enabledAdjustments.insert(adjustment)
                } else {
                    enabledAdjustments.remove(adjustment)
                }
            }
        )
    }
}

#Preview {
    ContentView()
}

private extension PhotoEditConfiguration.Adjustment {
    var displayTitle: String {
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
        @unknown default:
            return rawValue.capitalized
        }
    }
}
