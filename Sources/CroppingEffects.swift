//
//  CroppingEffects.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-22.
//

import Foundation

/// A single cropping effect with an associated parameter.
/// - dim(opacity): 0 = no dimming, 1 = fully black
/// - blur(radius): in points
/// - desaturate(amount): 0 = keep color, 1 = fully grayscale
nonisolated
public enum CroppingEffect: Codable, Hashable, Sendable {
    case dim(opacity: Double)
    case blur(radius: Double)
    case desaturate(amount: Double)
}

/// A combinable set of cropping effects.
public typealias CroppingEffectSet = Set<CroppingEffect>

public extension CroppingEffect {
    // Convenience constructors with common defaults
    static func dim(_ opacity: Double = 0.45) -> CroppingEffect { .dim(opacity: opacity) }
    static func blur(_ radius: Double = 8.0) -> CroppingEffect { .blur(radius: radius) }
    static func desaturate(_ amount: Double = 1.0) -> CroppingEffect { .desaturate(amount: amount) }
}
