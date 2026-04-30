import Foundation

struct MarkdownDocument: Equatable {
    var text: String
    var fileURL: URL?

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }

    /// The Markdown body with any leading YAML front-matter (`---` … `---`) removed.
    /// CommonMark has no concept of front-matter, so left in place it gets parsed as
    /// a thematic break followed by a setext heading, which renders horribly. We
    /// render the front-matter ourselves above the body instead — see `frontMatterText`.
    var bodyText: String { parsed.body }

    /// The raw text of any leading YAML front-matter, without the `---` delimiters,
    /// or `nil` if the document has none (or if the front-matter block isn't closed).
    var frontMatterText: String? { parsed.frontMatter }

    private var parsed: (frontMatter: String?, body: String) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return (nil, text)
        }

        let lines = normalized.components(separatedBy: "\n")
        for index in 1..<lines.count where lines[index].trimmingCharacters(in: .whitespaces) == "---" {
            let frontMatter = lines[1..<index].joined(separator: "\n")
            let body = lines[(index + 1)...].joined(separator: "\n")
            return (frontMatter, body)
        }
        return (nil, text)
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
