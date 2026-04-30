//
//  EditorOptionsPanel.swift
//  HiveCompose
//
//  Created by Codex on 2026-04-28.
//

import SwiftUI
import HiveCompose

struct EditorOptionsPanel: View {
    enum OptionsPanel: String, CaseIterable, Identifiable {
        case crop
        case adjustments

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    @Binding var selectedPanel: OptionsPanel
    @Binding var settings: DemoAppSettings

    let configurableAdjustments: [PhotoEditConfiguration.Adjustment]
    let persistSettings: () -> Void

    private var isCropEnabled: Binding<Bool> {
        Binding(
            get: { settings.enabledAdjustments.contains(.crop) },
            set: { isOn in
                var enabledAdjustments = settings.enabledAdjustments

                if isOn {
                    enabledAdjustments.insert(.crop)
                } else {
                    enabledAdjustments.remove(.crop)
                }

                settings.enabledAdjustments = enabledAdjustments
                persistSettings()
            }
        )
    }

    var body: some View {
        GroupBox("Editor Options") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Options Panel", selection: $selectedPanel) {
                    ForEach(OptionsPanel.allCases) { panel in
                        Text(panel.title).tag(panel)
                    }
                }
                .pickerStyle(.segmented)

                if selectedPanel == .crop {
                    CropOptionsView(
                        settings: $settings,
                        isCropEnabled: isCropEnabled,
                        persistSettings: persistSettings
                    )
                } else {
                    AdjustmentOptionsView(
                        settings: $settings,
                        adjustments: configurableAdjustments,
                        persistSettings: persistSettings
                    )
                }
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct CropOptionsView: View {
    @Binding var settings: DemoAppSettings
    let isCropEnabled: Binding<Bool>
    let persistSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Crop Tool", isOn: isCropEnabled)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                EffectToggleRow(
                    title: "Dim",
                    isEnabled: $settings.dimEnabled,
                    value: $settings.dimOpacity,
                    range: 0...1,
                    persistSettings: persistSettings
                )

                EffectToggleRow(
                    title: "Blur",
                    isEnabled: $settings.blurEnabled,
                    value: $settings.blurRadius,
                    range: 0...20,
                    persistSettings: persistSettings
                )

                EffectToggleRow(
                    title: "Desaturate",
                    isEnabled: $settings.desaturateEnabled,
                    value: $settings.desaturateAmount,
                    range: 0...1,
                    persistSettings: persistSettings
                )
            }
            .disabled(!settings.enabledAdjustments.contains(.crop))
            .opacity(settings.enabledAdjustments.contains(.crop) ? 1 : 0.45)
        }
    }
}

private struct AdjustmentOptionsView: View {
    @Binding var settings: DemoAppSettings

    let adjustments: [PhotoEditConfiguration.Adjustment]
    let persistSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("All On") {
                    var enabledAdjustments = settings.enabledAdjustments
                    enabledAdjustments.formUnion(adjustments)
                    settings.enabledAdjustments = enabledAdjustments
                    persistSettings()
                }
                .buttonStyle(.bordered)

                Button("All Off") {
                    var enabledAdjustments = settings.enabledAdjustments
                    enabledAdjustments.subtract(adjustments)
                    settings.enabledAdjustments = enabledAdjustments
                    persistSettings()
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12, alignment: .leading),
                    GridItem(.flexible(), spacing: 12, alignment: .leading)
                ],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(adjustments) { adjustment in
                    Toggle(
                        adjustment.displayTitle,
                        isOn: Binding(
                            get: { settings.enabledAdjustments.contains(adjustment) },
                            set: { isOn in
                                var enabledAdjustments = settings.enabledAdjustments

                                if isOn {
                                    enabledAdjustments.insert(adjustment)
                                } else {
                                    enabledAdjustments.remove(adjustment)
                                }

                                settings.enabledAdjustments = enabledAdjustments
                                persistSettings()
                            }
                        )
                    )
                }
            }
        }
    }
}

private struct EffectToggleRow: View {
    let title: String
    @Binding var isEnabled: Bool
    @Binding var value: Double
    let range: ClosedRange<Double>
    let persistSettings: () -> Void

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Text(title)
                Spacer()
                Slider(value: $value, in: range) {
                    Text("")
                }
                .frame(width: 160)
                .disabled(!isEnabled)
            }
        }
        .onChange(of: isEnabled) { _, _ in
            persistSettings()
        }
        .onChange(of: value) { _, _ in
            persistSettings()
        }
    }
}
