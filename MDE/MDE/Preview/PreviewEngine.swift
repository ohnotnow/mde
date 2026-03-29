import SwiftUI

protocol PreviewEngine {
    var id: String { get }
    var displayName: String { get }

    func makePreviewView(document: MarkdownDocument, settings: AppSettings) -> AnyView
}
