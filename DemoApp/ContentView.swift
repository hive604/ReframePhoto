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
    // Store only a lightweight reference (filename) in UserDefaults
    @AppStorage("selectedImageUUIDString") private var selectedImageUUIDString: String?

    // In-memory image for display
    @State private var displayedImage: UIImage?
    @State private var losslessEdits = LosslessEdits(crop: nil, rotation: .zero)

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingEditor = false
    @State private var selectedPanel: EditorOptionsPanel.OptionsPanel = .crop

    private var configurableAdjustments: [PhotoEditConfiguration.Adjustment] {
        PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop }
    }

    @State private var settings = DemoAppSettings.default

    private func persistSettingsModel() {
        guard let selectedImageUUIDString else { return }
        do {
            try AppDataStore.saveSettings(settings, uuid: selectedImageUUIDString)
        } catch {
            print("Failed to persist settings: \(error)")
        }
    }

    private func clearImage() {
        withAnimation {
            deleteImage()
            displayedImage = nil
            selectedImageUUIDString = nil
            settings = .default
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

                EditorOptionsPanel(
                    selectedPanel: $selectedPanel,
                    settings: $settings,
                    configurableAdjustments: configurableAdjustments,
                    persistSettings: persistSettingsModel
                )

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
                        croppingEffects: settings.croppingEffects,
                        allowedAdjustments: settings.enabledAdjustments
                    )
                    HiveCompose.PhotoEditor(
                        $losslessEdits,
                        image: uiImage,
                        configuration: config
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
                    losslessEdits = LosslessEdits(crop: nil, rotation: .zero)
                    settings = .default
                    persistSettingsModel()
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
    func saveImage(_ data: Data) throws {
        guard let selectedImageUUIDString else { return }
        try AppDataStore.saveImageData(data, uuid: selectedImageUUIDString)
    }

    func loadImage() {
        guard let selectedImageUUIDString else {
            clearImage()
            return
        }

        if let data = AppDataStore.loadImageData(uuid: selectedImageUUIDString),
           let image = UIImage(data: data) {
            displayedImage = image
        } else {
            clearImage()
            return
        }

        if let decodedEdits = AppDataStore.loadLosslessEdits(uuid: selectedImageUUIDString) {
            losslessEdits = decodedEdits
        }

        settings = AppDataStore.loadSettings(uuid: selectedImageUUIDString) ?? .default
    }

    func deleteImage() {
        if let selectedImageUUIDString {
            AppDataStore.deleteAllData(uuid: selectedImageUUIDString)
        }
    }

    private func persistLosslessEdits() {
        guard let selectedImageUUIDString else { return }
        do {
            try AppDataStore.saveLosslessEdits(losslessEdits, uuid: selectedImageUUIDString)
        } catch {
            print("Failed to persist lossless edits: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
