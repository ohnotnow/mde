import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    private let installedFontFamilies: [String] =
        NSFontManager.shared.availableFontFamilies.sorted()

    var body: some View {
        Form {
            Section("Reader") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(appModel.settings.readerFontSize)) pt")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: fontSizeBinding,
                        in: AppSettings.minimumFontSize...AppSettings.maximumFontSize,
                        step: 1
                    )

                    HStack {
                        Button("Smaller") {
                            appModel.decreaseFontSize()
                        }

                        Button("Larger") {
                            appModel.increaseFontSize()
                        }

                        Button("Reset") {
                            appModel.resetFontSize()
                        }
                    }
                }

                Picker("Font", selection: fontFamilyBinding) {
                    Section {
                        ForEach(ReaderFontFamily.presets) { family in
                            Text(family.label).tag(family)
                        }
                    }

                    Section("Installed Fonts") {
                        ForEach(installedFontFamilies, id: \.self) { name in
                            Text(name).tag(ReaderFontFamily.custom(name))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Line Height")
                        Spacer()
                        Text(String(format: "%.1f", appModel.settings.readerLineHeight))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: lineHeightBinding,
                        in: AppSettings.minimumLineHeight...AppSettings.maximumLineHeight,
                        step: 0.1
                    )
                }
            }

        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.readerFontSize },
            set: { appModel.updateFontSize(to: $0) }
        )
    }

    private var fontFamilyBinding: Binding<ReaderFontFamily> {
        Binding(
            get: { appModel.settings.readerFontFamily },
            set: { appModel.settings.readerFontFamily = $0 }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.readerLineHeight },
            set: {
                appModel.settings.readerLineHeight = $0
                appModel.settings.clampValues()
            }
        )
    }
}
