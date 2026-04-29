//
//  AppDataStore.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-28.
//

import Foundation

struct AppDataStore {
    // MARK: - Directories
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - URLs for a given UUID
    static func imageURL(for uuid: String) -> URL {
        documentsDirectory().appendingPathComponent("selected_\(uuid)")
    }

    static func settingsURL(for uuid: String) -> URL {
        documentsDirectory().appendingPathComponent("settings_\(uuid)")
    }

    // MARK: - Image IO
    static func saveImageData(_ data: Data, uuid: String) throws {
        let url = imageURL(for: uuid)
        try data.write(to: url, options: .atomic)
    }

    static func loadImageData(uuid: String) -> Data? {
        let url = imageURL(for: uuid)
        return try? Data(contentsOf: url)
    }

    static func deleteImage(uuid: String) {
        let url = imageURL(for: uuid)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Settings IO
    static func saveSettings(_ settings: SavedEditorSettings, uuid: String) throws {
        let url = settingsURL(for: uuid)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: url, options: .atomic)
    }

    static func loadSettings(uuid: String) -> SavedEditorSettings? {
        let url = settingsURL(for: uuid)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedEditorSettings.self, from: data)
    }

    static func deleteSettings(uuid: String) {
        let url = settingsURL(for: uuid)
        try? FileManager.default.removeItem(at: url)
    }
}
