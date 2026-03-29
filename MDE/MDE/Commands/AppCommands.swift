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
        }

        CommandMenu("Editor") {
            Button("Increase Font Size") {
                appModel.increaseFontSize()
            }
            .keyboardShortcut("=", modifiers: [.command])

            Button("Decrease Font Size") {
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
