import SwiftUI

protocol MarkdownRenderer {
    var id: String { get }
    var displayName: String { get }

    func makeRenderedView(document: MarkdownDocument, settings: AppSettings) -> AnyView
}
