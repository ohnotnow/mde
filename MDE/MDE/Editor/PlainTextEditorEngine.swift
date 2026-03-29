import SwiftUI

struct PlainTextEditorEngine: EditorEngine {
    let id = "plain-text"
    let displayName = "Plain Text"
    let capabilities: EditorCapabilities = []

    func makeEditorView(
        document: Binding<MarkdownDocument>,
        settings: AppSettings
    ) -> AnyView {
        AnyView(
            TextEditor(text: textBinding(for: document))
                .font(.system(size: settings.editorFontSize, design: .monospaced))
                .padding(12)
        )
    }

    func apply(_ command: EditorCommand, to document: Binding<MarkdownDocument>) {
        switch command {
        case .bold:
            wrapSelectionFallback(in: "**", document: document)
        case .italic:
            wrapSelectionFallback(in: "_", document: document)
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

    private func wrapSelectionFallback(
        in marker: String,
        document: Binding<MarkdownDocument>
    ) {
        var updated = document.wrappedValue
        updated.text += "\(marker)\(marker)"
        updated.isDirty = true
        document.wrappedValue = updated
    }
}
