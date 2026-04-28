//
//  PhotoEditConfiguration.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-25.
//

public struct PhotoEditConfiguration {
    public enum Adjustment: String, CaseIterable, Hashable, Identifiable {
        case crop
        case tilt
        case brightness
        case exposure
        case contrast
        case saturation
        case vibrance
        case sharpness
        case warmth
        case tint

        public var id: String { rawValue }
    }

    public var croppingEffects: CroppingEffectSet
    public var allowedAdjustments: Set<Adjustment>
    public var showFrames = false

    public init(
        croppingEffects: CroppingEffectSet = CroppingEffectSet([.dim(opacity: 0.4)]),
        allowedAdjustments: Set<Adjustment> = Set(Adjustment.allCases)
    ) {
        self.croppingEffects = croppingEffects
        self.allowedAdjustments = allowedAdjustments
    }
}
