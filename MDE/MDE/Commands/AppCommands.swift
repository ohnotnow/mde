import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var appModel: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
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

        CommandGroup(replacing: .saveItem) { }

        CommandMenu("View") {
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
