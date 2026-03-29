import SwiftUI

struct WorkspaceView: View {
    @Binding var document: MarkdownDocument
    @Binding var settings: AppSettings

    let editorEngine: any EditorEngine
    let previewEngine: any PreviewEngine

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                editorPane

                if settings.showPreview {
                    previewPane
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(documentTitle)
                .font(.headline)

            Spacer()

            Text("Editor: \(editorEngine.displayName)")
                .foregroundStyle(.secondary)

            if settings.showPreview {
                Text("Preview: \(previewEngine.displayName)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var editorPane: some View {
        editorEngine.makeEditorView(document: $document, settings: settings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPane: some View {
        previewEngine.makePreviewView(document: document)
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var documentTitle: String {
        document.isDirty ? "\(document.displayName) •" : document.displayName
    }
}
