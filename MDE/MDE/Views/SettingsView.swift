import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    private let installedFontFamilies: [String] =
        NSFontManager.shared.availableFontFamilies.sorted()

    private let installedEditors: [ExternalEditor] =
        ExternalEditorService().installedEditors()

    private let installedInternalEditors: [DetectedInternalEditor] =
        InternalEditorService().installedEditors()

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

            Section("External Editor") {
                Picker("Editor", selection: externalEditorBinding) {
                    Text("System Default").tag(ExternalEditorPreference.systemDefault)

                    if !installedEditors.isEmpty {
                        Section("Detected") {
                            ForEach(installedEditors) { editor in
                                Text(editor.displayName)
                                    .tag(ExternalEditorPreference.bundleID(editor.bundleID))
                            }
                        }
                    }

                    if case .customApp(let url) = appModel.settings.externalEditor {
                        Section("Custom") {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .tag(ExternalEditorPreference.customApp(url))
                        }
                    }
                }

                Button("Choose Other Application…") {
                    chooseCustomEditor()
                }

                Text("Used by File → Open in External Editor (⇧⌘E). The preview reloads automatically when the editor saves.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Internal Editor") {
                TextField("Command", text: internalEditorBinding, prompt: Text("e.g. nvim"))
                    .autocorrectionDisabled()

                if !installedInternalEditors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Detected on your PATH")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(installedInternalEditors) { editor in
                                Button(editor.displayName) {
                                    appModel.settings.internalEditorCommand = editor.command
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Text("Used by File → Quick Edit (⌘E) — runs inside an embedded terminal pane. TUI editors only; GUI editors with a `--wait` flag belong in the External Editor setting above.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

    private var externalEditorBinding: Binding<ExternalEditorPreference> {
        Binding(
            get: { appModel.settings.externalEditor },
            set: { appModel.settings.externalEditor = $0 }
        )
    }

    private var internalEditorBinding: Binding<String> {
        Binding(
            get: { appModel.settings.internalEditorCommand },
            set: { appModel.settings.internalEditorCommand = $0 }
        )
    }

    private func chooseCustomEditor() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an editor application."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        appModel.settings.externalEditor = .customApp(url)
    }
}
