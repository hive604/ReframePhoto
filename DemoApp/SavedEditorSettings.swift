//
//  SavedEditorSettings.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-28.
//

import HiveCompose

struct SavedEditorSettings: Codable {
    var losslessEdits: LosslessEdits
    var allowedAdjustmentRawValues: [String]
    var dimEnabled: Bool
    var dimOpacity: Double
    var blurEnabled: Bool
    var blurRadius: Double
    var desaturateEnabled: Bool
    var desaturateAmount: Double
}

