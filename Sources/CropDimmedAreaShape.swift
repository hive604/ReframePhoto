//
//  CropDimmedAreaShape.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-22.
//

import SwiftUI

struct CropDimmedAreaShape: Shape {
    let outerRect: CGRect
    let cropRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(outerRect)
        path.addRect(cropRect)
        return path
    }
}

#Preview {
    let outer = CGRect(x: 0, y: 0, width: 300, height: 200)
    let crop = CGRect(x: (outer.width - 160) / 2, y: (outer.height - 100) / 2, width: 160, height: 100)

    ZStack {
        // Background to better see the dimming effect
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                // Simple checkerboard for contrast
                VStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<15, id: \.self) { col in
                                Rectangle()
                                    .fill(((row + col) % 2 == 0) ? Color.white.opacity(0.15) : Color.black.opacity(0.15))
                            }
                        }
                    }
                }
            )
            .frame(width: outer.width, height: outer.height)

        CropDimmedAreaShape(outerRect: outer, cropRect: crop)
            .fill(.black.opacity(0.45), style: FillStyle(eoFill: true))
            .overlay {
                Rectangle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: crop.width, height: crop.height)
            }
    }
    .padding()
    .background(Color.black.opacity(0.1))
}
