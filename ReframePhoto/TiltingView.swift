//
//  TiltingView.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-22.
//

import SwiftUI

struct TiltingView: View {
    let image: Image
    let imageSize: CGSize
    let geometrySize: CGSize
    @Binding var rotationDegrees: Double
    let cropFrame: CGRect

    @ScaledMetric(relativeTo: .caption2) private var tiltLabelWidth: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var sliderWidth: CGFloat = 280

    private var rotation: Angle {
        .degrees(rotationDegrees)
    }

    var body: some View {
        let fittedSize = aspectFitSize(for: imageSize, in: geometrySize)
        let baseScale = rotationFitScale(for: fittedSize, angle: rotation)
        let cropCenterOffset = CGSize(
            width: cropFrame.midX - (geometrySize.width / 2),
            height: cropFrame.midY - (geometrySize.height / 2)
        )
        let cropScaleX = cropFrame.width > 0 ? geometrySize.width / cropFrame.width : 1
        let cropScaleY = cropFrame.height > 0 ? geometrySize.height / cropFrame.height : 1
        let cropScale = min(cropScaleX, cropScaleY)
        let displayedCropSize = CGSize(
            width: cropFrame.width * cropScale,
            height: cropFrame.height * cropScale
        )

        return VStack(spacing: 0) {
            ZStack {
                Color.black

                image
                    .resizable()
#if DEBUG
                    .border(.orange, width: 2)
#endif
                    .scaledToFit()
                    .scaleEffect(baseScale * cropScale)
                    .rotationEffect(rotation)
                    .offset(
                        x: -cropCenterOffset.width * cropScale,
                        y: -cropCenterOffset.height * cropScale
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask {
                        Rectangle()
                            .frame(width: displayedCropSize.width, height: displayedCropSize.height)
                            .position(x: geometrySize.width / 2, y: geometrySize.height / 2)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())

            HStack {
                Text("-15°")
                    .frame(width: tiltLabelWidth, alignment: .trailing)
                Slider(
                    value: $rotationDegrees,
                    in: -15 ... 15,
                    step: 0.1
                )
                .frame(maxWidth: sliderWidth)
                .tint(.white)
                Text("15°")
                    .frame(width: tiltLabelWidth, alignment: .leading)
            }
            .padding()
            .background(.regularMaterial)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return .zero
        }

        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let scale = min(widthScale, heightScale)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func rotationFitScale(for size: CGSize, angle: Angle) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        let rotatedSize = rotatedBoundingSize(for: size, angle: angle)
        guard rotatedSize.width > 0, rotatedSize.height > 0 else { return 1 }

        let horizontalScale = size.width / rotatedSize.width
        let verticalScale = size.height / rotatedSize.height

        return min(horizontalScale, verticalScale, 1)
    }

    private func rotatedBoundingSize(for size: CGSize, angle: Angle) -> CGSize {
        let radians = angle.radians
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))

        return CGSize(
            width: size.width * absoluteCosine + size.height * absoluteSine,
            height: size.width * absoluteSine + size.height * absoluteCosine
        )
    }
}
