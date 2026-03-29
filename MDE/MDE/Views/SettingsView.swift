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
}
