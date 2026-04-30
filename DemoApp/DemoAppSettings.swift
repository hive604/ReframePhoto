//
//  DemoAppSettings.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-28.
//

import HiveCompose

struct DemoAppSettings: Codable {
    var allowedAdjustmentRawValues: [String]
    var dimEnabled: Bool
    var dimOpacity: Double
    var blurEnabled: Bool
    var blurRadius: Double
    var desaturateEnabled: Bool
    var desaturateAmount: Double
}

extension DemoAppSettings {
    static let `default` = DemoAppSettings(
        allowedAdjustmentRawValues: PhotoEditConfiguration.Adjustment.allCases.map(\.rawValue).sorted(),
        dimEnabled: false,
        dimOpacity: 0.45,
        blurEnabled: false,
        blurRadius: 8,
        desaturateEnabled: false,
        desaturateAmount: 1
    )

    var enabledAdjustments: Set<PhotoEditConfiguration.Adjustment> {
        get {
            Set(allowedAdjustmentRawValues.compactMap(PhotoEditConfiguration.Adjustment.init(rawValue:)))
        }
        set {
            allowedAdjustmentRawValues = newValue.map(\.rawValue).sorted()
        }
    }

    var croppingEffects: CroppingEffectSet {
        var set: CroppingEffectSet = []

        if dimEnabled {
            set.insert(.dim(dimOpacity))
        }

        if blurEnabled {
            set.insert(.blur(blurRadius))
        }

        if desaturateEnabled {
            set.insert(.desaturate(desaturateAmount))
        }

        return set
    }
}
