//
//  CropBounds.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-05-02.
//

import SwiftUI

struct CropBounds {
    let maximumFrame: CGRect

    init(
        in bounds: CGRect,
        visibleImageSize: CGSize,
        rotation: Angle
    ) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let cosine = abs(cos(rotation.radians))
        let sine = abs(sin(rotation.radians))

        let rotatedSize = CGSize(
            width: visibleImageSize.width * cosine + visibleImageSize.height * sine,
            height: visibleImageSize.width * sine + visibleImageSize.height * cosine
        )

        maximumFrame = CGRect(
            x: center.x - rotatedSize.width / 2,
            y: center.y - rotatedSize.height / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )
    }
}
