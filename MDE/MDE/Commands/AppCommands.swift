import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var appModel: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                appModel.newDocument()
            }
            .keyboardShortcut("n")

            Button("Open...") {
                appModel.openDocument()
            }
            .keyboardShortcut("o")

            Menu("Open Recent") {
                if appModel.recentDocuments.isEmpty {
                    Button("No Recent Documents") { }
                        .disabled(true)
                } else {
                    ForEach(appModel.recentDocuments, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            appModel.openRecentDocument(url)
                        }
                    }

                    Divider()

                    Button("Clear Menu") {
                        appModel.clearRecentDocuments()
                    }
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                appModel.saveDocument()
            }
            .keyboardShortcut("s")
            .disabled(!appModel.canSave)

            Button("Save As...") {
                appModel.saveDocumentAs()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])
        }

        CommandMenu("View") {
            Button(appModel.settings.showPreview ? "Hide Preview" : "Show Preview") {
                appModel.togglePreview()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Divider()

            Button("Zoom In") {
                appModel.increaseFontSize()
            }
            .keyboardShortcut("=", modifiers: [.command])

            Button("Zoom Out") {
                appModel.decreaseFontSize()
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Actual Size") {
                appModel.resetFontSize()
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}
