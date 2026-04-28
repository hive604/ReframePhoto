//
//  CropConstraint.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-18.
//

import CoreGraphics

public enum CropConstraint: String, CaseIterable, Hashable, Codable {
    case freeform = "free"
    case square = "1:1"
    case fourThreeLandscape = "4:3"
    case fourThreePortrait = "3:4"
    case fiveThreeLandscape = "5:3"
    case fiveThreePortrait = "3:5"
    case sixteenNineLandscape = "16:9"
    case sixteenNinePortrait = "9:16"

    private var definition: (numerator: Int, denominator: Int)? {
        switch self {
        case .freeform:
            return nil
        case .square:
            return (1, 1)
        case .fourThreeLandscape:
            return (4, 3)
        case .fourThreePortrait:
            return (3, 4)
        case .fiveThreeLandscape:
            return (5, 3)
        case .fiveThreePortrait:
            return (3, 5)
        case .sixteenNineLandscape:
            return (16, 9)
        case .sixteenNinePortrait:
            return (9, 16)
        }
    }

    var label: String {
        isFreeform ? "FREE" : rawValue
    }

    var ratio: CGFloat? {
        guard let definition else { return nil }
        return CGFloat(definition.numerator) / CGFloat(definition.denominator)
    }

    var isFreeform: Bool {
        self == .freeform
    }

    static let displayOrder: [CropConstraint] = [
        .freeform,
        .square,
        .fourThreePortrait,
        .fourThreeLandscape,
        .fiveThreePortrait,
        .fiveThreeLandscape,
        .sixteenNinePortrait,
        .sixteenNineLandscape
    ]
}
