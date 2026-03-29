import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Editor") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(appModel.settings.editorFontSize)) pt")
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
                    ForEach(EditorFontFamily.allCases) { family in
                        Text(family.label).tag(family)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Line Height")
                        Spacer()
                        Text(String(format: "%.1f", appModel.settings.editorLineHeight))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: lineHeightBinding,
                        in: AppSettings.minimumLineHeight...AppSettings.maximumLineHeight,
                        step: 0.1
                    )
                }

                Toggle("Show line numbers", isOn: showLineNumbersBinding)
                Toggle("Wrap long lines", isOn: wrapLinesBinding)
                Toggle("Hide Markdown syntax on inactive lines", isOn: hideSyntaxBinding)
                Toggle("Show preview by default", isOn: showPreviewBinding)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.editorFontSize },
            set: { appModel.updateFontSize(to: $0) }
        )
    }

    private var showPreviewBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.showPreview },
            set: { newValue in
                appModel.settings.showPreview = newValue
            }
        )
    }

    private var fontFamilyBinding: Binding<EditorFontFamily> {
        Binding(
            get: { appModel.settings.editorFontFamily },
            set: { appModel.settings.editorFontFamily = $0 }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.editorLineHeight },
            set: { appModel.updateLineHeight(to: $0) }
        )
    }

    private var showLineNumbersBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.showLineNumbers },
            set: { appModel.settings.showLineNumbers = $0 }
        )
    }

    private var wrapLinesBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.wrapLines },
            set: { appModel.settings.wrapLines = $0 }
        )
    }

    private var hideSyntaxBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.hideSyntax },
            set: { appModel.settings.hideSyntax = $0 }
        )
    }
}
