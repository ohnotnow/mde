import MarkdownEditor
import SwiftUI

struct CodeMirrorEditorEngine: EditorEngine {
    let id = "codemirror"
    let displayName = "MarkdownEditor"
    let capabilities: EditorCapabilities = [
        .syntaxHighlighting,
        .inlineImages,
        .richTextFormatting,
        .liveInlineRendering
    ]

    func makeEditorView(
        document: Binding<MarkdownDocument>,
        settings: AppSettings
    ) -> AnyView {
        AnyView(
            EditorWebView(
                text: textBinding(for: document),
                configuration: EditorConfiguration(
                    fontSize: settings.editorFontSize,
                    fontFamily: "Menlo, Monaco, monospace",
                    lineHeight: 1.5,
                    showLineNumbers: true,
                    wrapLines: true,
                    renderMermaid: false,
                    renderMath: true,
                    renderImages: true,
                    hideSyntax: false
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    func apply(_ command: EditorCommand, to document: Binding<MarkdownDocument>) {
        switch command {
        case .bold:
            append(marker: "**", to: document)
        case .italic:
            append(marker: "_", to: document)
        }
    }

    private func textBinding(for document: Binding<MarkdownDocument>) -> Binding<String> {
        Binding(
            get: { document.wrappedValue.text },
            set: { newValue in
                var updated = document.wrappedValue
                updated.text = newValue
                updated.isDirty = true
                document.wrappedValue = updated
            }
        )
    }

    private func append(marker: String, to document: Binding<MarkdownDocument>) {
        var updated = document.wrappedValue
        updated.text += "\(marker)\(marker)"
        updated.isDirty = true
        document.wrappedValue = updated
    }
}
