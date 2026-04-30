//
//  PhotoEditConfiguration+DisplayTitle.swift
//  HiveCompose
//
//  Created by Codex on 2026-04-28.
//

import Foundation
import HiveCompose

extension PhotoEditConfiguration.Adjustment {
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
