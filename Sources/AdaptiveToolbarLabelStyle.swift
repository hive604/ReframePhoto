//
//  AdaptiveToolbarLabelStyle.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-24.
//


import SwiftUI

struct AdaptiveToolbarLabelStyle: LabelStyle {
    let showsTitle: Bool
    @ScaledMetric private var symbolWidth = 28
    @ScaledMetric private var spacing = 6
    @ScaledMetric private var titleWidth = 100

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
                .frame(width: symbolWidth, alignment: .center)

            if showsTitle {
                configuration.title
                    .frame(width: titleWidth, alignment: .leading)
            }
        }
    }
}
