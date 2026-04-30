import Foundation

struct MarkdownDocument: Equatable {
    var text: String
    var fileURL: URL?

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }
}

extension MarkdownDocument {
    static let empty = MarkdownDocument(
        text: "",
        fileURL: nil
    )

    static let sample = MarkdownDocument(
        text: """
        # MDE

        A calmer first step is a **native Markdown reader** with a solid macOS shell.

        ## What this cut focuses on

        - Opening Markdown files from the app, Finder, or drag and drop
        - Comfortable typography for longer reading sessions
        - Zoom controls and lightweight reader settings
        - A simpler architecture centered on rendering quality first

        > This app is a viewer. Rendering is the product.
        """,
        fileURL: nil
    )
}
