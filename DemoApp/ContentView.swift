//
//  ContentView.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import PhotosUI
import HiveCompose

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
    @State private var losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingEditor = false
    @State private var selectedPanel: OptionsPanel = .crop

    // Cropping effects state
    @State private var croppingEffects: CroppingEffectSet = []

    private var configurableAdjustments: [PhotoEditConfiguration.Adjustment] {
        PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop }
    }

    // New bindings for updated editing model state:
    @State private var settings = DemoAppSettings(
        allowedAdjustmentRawValues: PhotoEditConfiguration.Adjustment.allCases.map(\.rawValue).sorted(),
        dimEnabled: false,
        dimOpacity: 0.45,
        blurEnabled: false,
        blurRadius: 8,
        desaturateEnabled: false,
        desaturateAmount: 1
    )

    private var enabledAdjustmentsBinding: Binding<Set<PhotoEditConfiguration.Adjustment>> {
        Binding(
            get: {
                Set(settings.allowedAdjustmentRawValues.compactMap(PhotoEditConfiguration.Adjustment.init(rawValue:)))
            }, set: { newValue in
                settings.allowedAdjustmentRawValues = newValue.map(\.rawValue).sorted()
            }
        )
    }

    private func persistSettingsModel() {
        guard let settingsURL else { return }
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to persist settings: \(error)")
        }
    }

    fileprivate func clearImage() {
        withAnimation {
            deleteImage()
            displayedImage = nil
            selectedImageUUIDString = nil

            // Reset settings model instead of individual state vars
            settings = DemoAppSettings(
                allowedAdjustmentRawValues: PhotoEditConfiguration.Adjustment.allCases.map(\.rawValue).sorted(),
                dimEnabled: false,
                dimOpacity: 0.45,
                blurEnabled: false,
                blurRadius: 8,
                desaturateEnabled: false,
                desaturateAmount: 1
            )
            rebuildEffectsFromSettings()
        }
    }

    func rebuildEffectsFromSettings() {
        var set: CroppingEffectSet = []
        if settings.dimEnabled { set.insert(.dim(settings.dimOpacity)) }
        if settings.blurEnabled { set.insert(.blur(settings.blurRadius)) }
        if settings.desaturateEnabled { set.insert(.desaturate(settings.desaturateAmount)) }
        croppingEffects = set
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
                                Toggle("Enable Crop Tool", isOn: Binding(
                                    get: { enabledAdjustmentsBinding.wrappedValue.contains(.crop) },
                                    set: { isOn in
                                        var set = enabledAdjustmentsBinding.wrappedValue
                                        if isOn { set.insert(.crop) } else { set.remove(.crop) }
                                        enabledAdjustmentsBinding.wrappedValue = set
                                        persistSettingsModel()
                                    }
                                ))

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $settings.dimEnabled) {
                                        HStack {
                                            Text("Dim")
                                            Spacer()
                                            Slider(value: $settings.dimOpacity, in: 0...1) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!settings.dimEnabled)
                                        }
                                    }
                                    .onChange(of: settings.dimEnabled) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }
                                    .onChange(of: settings.dimOpacity) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }

                                    Toggle(isOn: $settings.blurEnabled) {
                                        HStack {
                                            Text("Blur")
                                            Spacer()
                                            Slider(value: $settings.blurRadius, in: 0...20) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!settings.blurEnabled)
                                        }
                                    }
                                    .onChange(of: settings.blurEnabled) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }
                                    .onChange(of: settings.blurRadius) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }

                                    Toggle(isOn: $settings.desaturateEnabled) {
                                        HStack {
                                            Text("Desaturate")
                                            Spacer()
                                            Slider(value: $settings.desaturateAmount, in: 0...1) { Text("") }
                                                .frame(width: 160)
                                                .disabled(!settings.desaturateEnabled)
                                        }
                                    }
                                    .onChange(of: settings.desaturateEnabled) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }
                                    .onChange(of: settings.desaturateAmount) { _, _ in rebuildEffectsFromSettings(); persistSettingsModel() }
                                }
                                .disabled(!enabledAdjustmentsBinding.wrappedValue.contains(.crop))
                                .opacity(enabledAdjustmentsBinding.wrappedValue.contains(.crop) ? 1 : 0.45)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Button("All On") {
                                        var set = enabledAdjustmentsBinding.wrappedValue
                                        set.formUnion(PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop })
                                        enabledAdjustmentsBinding.wrappedValue = set
                                        persistSettingsModel()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("All Off") {
                                        var set = enabledAdjustmentsBinding.wrappedValue
                                        set.subtract(PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop })
                                        enabledAdjustmentsBinding.wrappedValue = set
                                        persistSettingsModel()
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
                                    ForEach(PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop }) { adjustment in
                                        Toggle(
                                            adjustment.displayTitle,
                                            isOn: Binding(
                                                get: { enabledAdjustmentsBinding.wrappedValue.contains(adjustment) },
                                                set: { isOn in
                                                    var set = enabledAdjustmentsBinding.wrappedValue
                                                    if isOn { set.insert(adjustment) } else { set.remove(adjustment) }
                                                    enabledAdjustmentsBinding.wrappedValue = set
                                                    persistSettingsModel()
                                                }
                                            )
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
                        allowedAdjustments: enabledAdjustmentsBinding.wrappedValue
                    )
                    HiveCompose.PhotoEditor(
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
                    losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
                    persistLosslessEdits()
                }
            } catch {
                print("Failed to load/persist image: \(error)")
            }
        }
        .onChange(of: losslessEdits) { _, _ in
            persistLosslessEdits()
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

    private var editsURL: URL? {
        selectedImageUUIDString != nil ? documentsDirectory().appendingPathComponent("edits_\(selectedImageUUIDString!)") : nil
    }

    func saveImage(_ data: Data) throws {
        // Store the original bytes as-is with a neutral filename (no extension)
        try data.write(to: imageURL!, options: .atomic)
    }

    func loadImage() {
        if let imageURL, let data = try? Data(contentsOf: imageURL), let image = UIImage(data: data) {
            displayedImage = image
        } else {
            clearImage()
        }

        if let editsURL, let data = try? Data(contentsOf: editsURL) {
            if let decoded = try? JSONDecoder().decode(LosslessEdits.self, from: data) {
                losslessEdits = decoded
            }
        }

        if let settingsURL, let data = try? Data(contentsOf: settingsURL) {
            if let decoded = try? JSONDecoder().decode(DemoAppSettings.self, from: data) {
                settings = decoded
                rebuildEffectsFromSettings()
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
        if let editsURL {
            try? FileManager.default.removeItem(at: editsURL)
        }
        selectedImageUUIDString = nil
    }

    private func persistLosslessEdits() {
        guard let editsURL else { return }
        do {
            let data = try JSONEncoder().encode(losslessEdits)
            try data.write(to: editsURL, options: .atomic)
        } catch {
            print("Failed to persist lossless edits: \(error)")
        }
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
