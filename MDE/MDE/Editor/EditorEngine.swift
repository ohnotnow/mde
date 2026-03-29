import SwiftUI

struct EditorCapabilities: OptionSet {
    let rawValue: Int

    static let syntaxHighlighting = EditorCapabilities(rawValue: 1 << 0)
    static let inlineImages = EditorCapabilities(rawValue: 1 << 1)
    static let richTextFormatting = EditorCapabilities(rawValue: 1 << 2)
    static let liveInlineRendering = EditorCapabilities(rawValue: 1 << 3)
}

enum EditorCommand {
    case bold
    case italic
}

protocol EditorEngine {
    var id: String { get }
    var displayName: String { get }
    var capabilities: EditorCapabilities { get }

    func makeEditorView(
        document: Binding<MarkdownDocument>,
        settings: AppSettings
    ) -> AnyView

    func apply(_ command: EditorCommand, to document: Binding<MarkdownDocument>)

    func customCSS(for settings: AppSettings) -> String?
}

extension EditorEngine {
    func customCSS(for settings: AppSettings) -> String? {
        nil
    }
}
