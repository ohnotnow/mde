import Highlightr
import MarkdownUI
import SwiftUI

struct NordSyntaxHighlighter: CodeSyntaxHighlighter {
    static let shared: NordSyntaxHighlighter? = NordSyntaxHighlighter()

    private let highlightr: Highlightr

    private init?() {
        guard let highlightr = Highlightr() else {
            return nil
        }
        highlightr.setTheme(to: "nord")
        self.highlightr = highlightr
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        let attributed = highlightr.highlight(
            content,
            as: language?.lowercased(),
            fastRender: true
        )

        guard let attributed else {
            return Text(content)
        }

        let stripped = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: stripped.length)
        stripped.removeAttribute(.font, range: fullRange)
        stripped.removeAttribute(.paragraphStyle, range: fullRange)

        return Text(AttributedString(stripped))
    }
}
