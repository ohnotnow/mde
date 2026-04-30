import AppKit
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var appModel: AppModel
    @FocusedValue(\.readerNavigator) private var readerNavigator: ReaderNavigator?

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

            Divider()

            Button("Close") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w")
        }

        CommandGroup(replacing: .saveItem) { }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Find...") {
                readerNavigator?.showFindBar()
            }
            .keyboardShortcut("f")
            .disabled(readerNavigator == nil)
        }

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

            Divider()

            Button("Top of Document") {
                readerNavigator?.scrollToTop()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(readerNavigator == nil)

            Button("Bottom of Document") {
                readerNavigator?.scrollToBottom()
            }
            .keyboardShortcut(.downArrow, modifiers: [.command])
            .disabled(readerNavigator == nil)
        }
    }
}
