//
//  LosslessEdits.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI

struct LosslessEdits: Codable, Hashable {
    /// Image center is 0.0.
    /// Thanks to rotation, this can extend past (-0.5...0.5).
    var crop: CGRect?

    /// Rotation of image.
    var rotation: Angle
}
