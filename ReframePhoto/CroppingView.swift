//
//  CroppingView.swift
//  ReframePhoto
//
//  Created by Steven Fisher on 2026-04-22.
//

import SwiftUI

struct CroppingView: View {
    let image: Image
    let fittedSize: CGSize
    let rotation: Angle
    let geometrySize: CGSize
    let cropFrame: CGRect
    let croppingEffects: CroppingEffectSet
    let onReset: () -> Void
    let onTranslate: (CGSize) -> Void
    let onResizeCorner: (CropCornerHandle, CGSize) -> Void
    let onResizeEdge: (CropEdgeHandle, CGSize) -> Void
    let onEndGesture: () -> Void

    private let cropHandleSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                baseImage

                if blurRadius > 0 || desaturateAmount > 0 {
                    outsideCropEffectImage
                        .mask(
                            CropDimmedAreaShape(
                                outerRect: CGRect(origin: .zero, size: geometrySize),
                                cropRect: cropFrame
                            )
                            .fill(style: FillStyle(eoFill: true, antialiased: false))
                        )
                }

                CropDimmedAreaShape(
                    outerRect: CGRect(origin: .zero, size: geometrySize),
                    cropRect: cropFrame
                )
                .fill(.black.opacity(dimOpacity), style: FillStyle(eoFill: true))

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .overlay {
                        Rectangle()
                            .stroke(.white, lineWidth: 2)
                    }
                    .frame(width: cropFrame.width, height: cropFrame.height)
                    .position(x: cropFrame.midX, y: cropFrame.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                onTranslate(value.translation)
                            }
                            .onEnded { _ in
                                onEndGesture()
                            }
                    )

                cropEdgeHandle(.top)
                cropEdgeHandle(.bottom)
                cropEdgeHandle(.left)
                cropEdgeHandle(.right)

                cropCornerHandle(.topLeft)
                cropCornerHandle(.topRight)
                cropCornerHandle(.bottomLeft)
                cropCornerHandle(.bottomRight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()

                Button("Reset Crop") {
                    onReset()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.ultraThinMaterial)
        }
    }

    private func cropCornerHandle(_ handle: CropCornerHandle) -> some View {
        Circle()
            .fill(.white)
            .frame(width: cropHandleSize, height: cropHandleSize)
            .overlay {
                Circle().stroke(.black.opacity(0.35), lineWidth: 1)
            }
            .position(position(for: handle, in: cropFrame))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onResizeCorner(handle, value.translation)
                    }
                    .onEnded { _ in
                        onEndGesture()
                    }
            )
    }

    private func position(for handle: CropCornerHandle, in cropFrame: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .topRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .bottomLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .bottomRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        }
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

    private func cropEdgeHandle(_ handle: CropEdgeHandle) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .frame(
                width: edgeHandleSize(for: handle).width,
                height: edgeHandleSize(for: handle).height
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(.black.opacity(0.35), lineWidth: 1)
            }
            .position(position(for: handle, in: cropFrame))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onResizeEdge(handle, value.translation)
                    }
                    .onEnded { _ in
                        onEndGesture()
                    }
            )
    }

    private func edgeHandleSize(for handle: CropEdgeHandle) -> CGSize {
        switch handle {
        case .top, .bottom:
            return CGSize(width: cropHandleSize * 1.6, height: cropHandleSize * 0.6)
        case .left, .right:
            return CGSize(width: cropHandleSize * 0.6, height: cropHandleSize * 1.6)
        }
    }

    private func position(for handle: CropEdgeHandle, in cropFrame: CGRect) -> CGPoint {
        switch handle {
        case .top:
            return CGPoint(x: cropFrame.midX, y: cropFrame.minY)
        case .bottom:
            return CGPoint(x: cropFrame.midX, y: cropFrame.maxY)
        case .left:
            return CGPoint(x: cropFrame.minX, y: cropFrame.midY)
        case .right:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.midY)
        }
    }

    private var baseImage: some View {
        image
            .resizable()
#if DEBUG
            .border(.orange, width: 2)
#endif
            .scaledToFit()
            .scaleEffect(rotationFitScale(for: fittedSize, angle: rotation))
            .rotationEffect(rotation)
            .frame(width: geometrySize.width, height: geometrySize.height)
            .position(x: geometrySize.width / 2, y: geometrySize.height / 2)
    }

    private var outsideCropEffectImage: some View {
        baseImage
            .saturation(max(0, 1 - desaturateAmount))
            .blur(radius: blurRadius)
    }

    // MARK: - Effect Helpers
    private var blurRadius: CGFloat {
        for effect in croppingEffects {
            if case let .blur(radius) = effect { return max(0, CGFloat(radius)) }
        }
        return 0
    }

    private var desaturateAmount: Double {
        for effect in croppingEffects {
            if case let .desaturate(amount) = effect { return max(0, min(1, amount)) }
        }
        return 0
    }

    private var dimOpacity: Double {
        for effect in croppingEffects {
            if case let .dim(opacity) = effect { return max(0, min(1, opacity)) }
        }
        return 0
    }
}
