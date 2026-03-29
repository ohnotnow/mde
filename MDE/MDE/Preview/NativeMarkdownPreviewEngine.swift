import SwiftUI

struct NativeMarkdownPreviewEngine: PreviewEngine {
    let id = "native-markdown-preview"
    let displayName = "Native Preview"

    func makePreviewView(document: MarkdownDocument, settings: AppSettings) -> AnyView {
        AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(renderedText(from: document.text))
                        .font(.system(size: settings.editorFontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        )
    }

    private func renderedText(from markdown: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full
                )
            )
        } catch {
            return AttributedString(markdown)
        }
    }
}
