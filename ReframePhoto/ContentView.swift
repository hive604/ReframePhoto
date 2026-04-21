//
//  ContentView.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    // Store only a lightweight reference (filename) in UserDefaults
    @AppStorage("selectedImageFilename") private var selectedImageFilename: String?

    // In-memory image for display
    @State private var displayedImage: UIImage?

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var losslessEdits = LosslessEdits(crop: .zero, rotation: .zero)
    @State private var isShowingEditor = false

    private var editsURL: URL { documentsDirectory().appendingPathComponent("edits.json") }

    fileprivate func clearImage() {
        withAnimation {
            deleteImage()
            displayedImage = nil
            selectedImageFilename = nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let uiImage = displayedImage {
                        Image(uiImage: uiImage)
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

                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                        Label("Pick Photo", systemImage: "photo")
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
                    ReframePhotoEditor(
                        image: Image(uiImage: uiImage),
                        edits: $losslessEdits,
                        onCancel: { isShowingEditor = false },
                        onConfirm: {
                            persistLosslessEdits()
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
                    let filename = try saveImage(data)
                    selectedImageFilename = filename
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

    func saveImage(_ data: Data) throws -> String {
        // Store the original bytes as-is with a neutral filename (no extension)
        let filename = "selected_\(UUID().uuidString)"
        let url = documentsDirectory().appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func persistLosslessEdits() {
        do {
            let data = try JSONEncoder().encode(losslessEdits)
            try data.write(to: editsURL, options: .atomic)
        } catch {
            print("Failed to persist edits: \(error)")
        }
    }

    func loadImage() {
        guard let filename = selectedImageFilename else { return }
        let url = documentsDirectory().appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            displayedImage = image
        } else {
            // File missing or unreadable; clean up the stored reference
            selectedImageFilename = nil
            displayedImage = nil
        }

        if let data = try? Data(contentsOf: editsURL) {
            if let decoded = try? JSONDecoder().decode(LosslessEdits.self, from: data) {
                losslessEdits = decoded
            }
        }
    }

    func deleteImage() {
        guard let filename = selectedImageFilename else { return }
        let url = documentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

#Preview {
    ContentView()
}
