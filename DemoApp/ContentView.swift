//
//  ContentView.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import PhotosUI
import Reframe

private struct SavedEditorSettings: Codable {
    var losslessEdits: LosslessEdits
    var dimEnabled: Bool
    var dimOpacity: Double
    var blurEnabled: Bool
    var blurRadius: Double
    var desaturateEnabled: Bool
    var desaturateAmount: Double
}

struct ContentView: View {
    // Store only a lightweight reference (filename) in UserDefaults
    @AppStorage("selectedImageUUIDString") private var selectedImageUUIDString: String?

    // In-memory image for display
    @State private var displayedImage: UIImage?

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
    @State private var isShowingEditor = false

    // Cropping effects state
    @State private var croppingEffects: CroppingEffectSet = []
    @State private var dimEnabled: Bool = false
    @State private var dimOpacity: Double = 0.45
    @State private var blurEnabled: Bool = false
    @State private var blurRadius: Double = 8
    @State private var desaturateEnabled: Bool = false
    @State private var desaturateAmount: Double = 1

    fileprivate func clearImage() {
        withAnimation {
            deleteImage()
            losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
            displayedImage = nil
            selectedImageUUIDString = nil

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

                GroupBox("Crop Tool Options") {
                    // Effects controls
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
                }
                .padding(.horizontal)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity, alignment: .center)
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
                    Reframe.PhotoEditor(
                        uiImage: uiImage,
                        edits: $losslessEdits,
                        croppingEffects: croppingEffects,
                        onCancel: { isShowingEditor = false },
                        onConfirm: {
                            persistEditorSettings()
                            isShowingEditor = false
                        }
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
}

#Preview {
    ContentView()
}
