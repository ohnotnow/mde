import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var document = MarkdownDocument.sample
    @Published var settings = AppSettings()

    let editorEngine: any EditorEngine
    let previewEngine: any PreviewEngine

    init() {
        self.editorEngine = PlainTextEditorEngine()
        self.previewEngine = NativeMarkdownPreviewEngine()
    }
}
