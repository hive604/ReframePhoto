//
//  CircularSymbolButton.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-23.
//

import SwiftUI

struct CircularSymbolButton: View {
    let systemName: String
    let action: () -> Void

    @ViewBuilder
    private func circularSymbolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.ultraThickMaterial, in: Circle())
        }
        .buttonStyle(CircularSymbolButtonStyle())
    }

    private struct CircularSymbolButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(.white)
                .background {
                    Circle()
                        .fill(.black.opacity(configuration.isPressed ? 0.8 : 0.6))
                }
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    var body: some View {
        circularSymbolButton(systemName: systemName, action: action)
    }
}
