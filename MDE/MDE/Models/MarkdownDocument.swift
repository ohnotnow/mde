import Foundation

struct MarkdownDocument: Equatable {
    var text: String
    var fileURL: URL?
    var isDirty: Bool

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }
}

extension MarkdownDocument {
    static let sample = MarkdownDocument(
        text: """
        # MDE

        This project starts with an editor engine seam.

        - The app owns document state, commands, and settings.
        - The editor pane is swappable.
        - The preview pane is separate from the editor implementation.
        """,
        fileURL: nil,
        isDirty: false
    )
}
