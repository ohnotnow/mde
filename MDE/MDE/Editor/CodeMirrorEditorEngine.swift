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
                    fontFamily: settings.editorFontFamily.cssValue,
                    lineHeight: settings.editorLineHeight,
                    showLineNumbers: settings.showLineNumbers,
                    wrapLines: settings.wrapLines,
                    renderMermaid: false,
                    renderMath: true,
                    renderImages: true,
                    hideSyntax: settings.hideSyntax
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

    func customCSS(for settings: AppSettings) -> String? {
        let horizontalPadding = settings.showLineNumbers ? 10 : 8
        let gutterPadding = settings.showLineNumbers ? 10 : 8

        return """
        .cm-content {
          padding-top: 14px !important;
          padding-right: 16px !important;
          padding-bottom: 18px !important;
          padding-left: \(horizontalPadding)px !important;
        }
        .cm-gutter.cm-lineNumbers .cm-gutterElement {
          padding-left: \(gutterPadding)px !important;
          padding-right: 8px !important;
        }
        .cm-line:has(.tok-meta) {
          background-color: transparent !important;
          border-radius: 0 !important;
        }
        .tok-meta {
          opacity: 0.52 !important;
          font-size: 0.9em !important;
        }
        """
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
