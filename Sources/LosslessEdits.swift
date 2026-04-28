//
//  LosslessEdits.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import Foundation
import UIKit

nonisolated
public struct LosslessEdits: Codable, Hashable {
    /// Image center is 0.0.
    /// Thanks to rotation, this can extend past (-0.5...0.5).
    public var crop: CGRect?

    /// The selected aspect-ratio constraint for the crop tool.
    ///
    /// This is persisted with the edit state for UI restoration, but it does not
    /// affect image rendering in `UIImage.applying(_:)`.
    public var cropConstraint: CropConstraint

    /// Rotation of image.
    var rotation: Double

    /// Brightness adjustment applied by Core Image color controls.
    ///
    /// `0` is neutral. Negative values darken the image and positive values brighten it.
    public var brightness: Double

    /// Exposure adjustment applied by Core Image exposure filtering.
    ///
    /// `0` is neutral. Negative values darken the image and positive values brighten it.
    public var exposure: Double

    /// Contrast adjustment applied by Core Image color controls.
    ///
    /// `1` is neutral. Values below `1` reduce contrast and values above `1` increase it.
    public var contrast: Double

    /// Saturation adjustment applied by Core Image color controls.
    ///
    /// `1` is neutral. `0` produces a grayscale image and larger values increase color intensity.
    public var saturation: Double

    /// Vibrance adjustment applied by Core Image vibrance filtering.
    ///
    /// `0` is neutral. Negative values mute less-saturated colors and positive values enhance them.
    public var vibrance: Double

    /// Sharpness adjustment applied by Core Image sharpen luminance filtering.
    ///
    /// `0` is neutral. Positive values increase edge contrast and perceived detail.
    public var sharpness: Double

    /// White-balance temperature adjustment.
    ///
    /// `0` is neutral. Negative values cool the image and positive values warm it.
    public var warmth: Double

    /// White-balance tint adjustment.
    ///
    /// `0` is neutral. Negative values push the image toward green and positive values toward magenta.
    public var tint: Double

    /// Creates a lossless edit description for a photo.
    public init(
        crop: CGRect? = nil,
        cropConstraint: CropConstraint = .freeform,
        rotation: Double,
        brightness: Double = 0.0,
        exposure: Double = 0.0,
        contrast: Double = 1.0,
        saturation: Double = 1.0,
        vibrance: Double = 0.0,
        sharpness: Double = 0.0,
        warmth: Double = 0.0,
        tint: Double = 0.0
    ) {
        self.crop = crop
        self.cropConstraint = cropConstraint
        self.rotation = rotation
        self.brightness = brightness
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.vibrance = vibrance
        self.sharpness = sharpness
        self.warmth = warmth
        self.tint = tint
    }

    enum CodingKeys: String, CodingKey {
        case crop
        case cropConstraint
        case rotation
        case brightness
        case exposure
        case contrast
        case saturation
        case vibrance
        case sharpness
        case warmth
        case tint
    }

    /// Creates an edit description by decoding previously serialized state.
    ///
    /// Missing fields are restored using backward-compatible default values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        crop = try container.decodeIfPresent(CGRect.self, forKey: .crop)
        cropConstraint = try container.decodeIfPresent(CropConstraint.self, forKey: .cropConstraint) ?? .freeform
        rotation = try container.decode(Double.self, forKey: .rotation)
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.0
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0.0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
        vibrance = try container.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0.0
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0.0
        warmth = try container.decodeIfPresent(Double.self, forKey: .warmth) ?? 0.0
        tint = try container.decodeIfPresent(Double.self, forKey: .tint) ?? 0.0
    }

    /// Encodes the complete edit description for persistence or transfer.
    ///
    /// This includes UI-restoration state such as `cropConstraint`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(crop, forKey: .crop)
        try container.encode(cropConstraint, forKey: .cropConstraint)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(exposure, forKey: .exposure)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(vibrance, forKey: .vibrance)
        try container.encode(sharpness, forKey: .sharpness)
        try container.encode(warmth, forKey: .warmth)
        try container.encode(tint, forKey: .tint)
    }
}
