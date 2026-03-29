import SwiftUI

struct WorkspaceView: View {
    @Binding var document: MarkdownDocument
    @Binding var settings: AppSettings

    let editorEngine: any EditorEngine
    let previewEngine: any PreviewEngine
    let onIncreaseFontSize: () -> Void
    let onDecreaseFontSize: () -> Void
    let onResetFontSize: () -> Void
    let onOpenDroppedFile: (URL) -> Void

    @State private var isDropTargeted = false

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
        .dropDestination(for: URL.self) { items, _ in
            guard let url = items.first else {
                return false
            }

            onOpenDroppedFile(url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 4, dash: [10]))
                    .padding(16)
                    .overlay {
                        Text("Drop a Markdown file to open it")
                            .font(.title3.weight(.semibold))
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(documentTitle)
                .font(.headline)

            Spacer()

            Button(settings.showPreview ? "Hide Preview" : "Show Preview") {
                settings.showPreview.toggle()
            }

            HStack(spacing: 6) {
                Button {
                    onDecreaseFontSize()
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }

                Text("\(Int(settings.editorFontSize)) pt")
                    .monospacedDigit()
                    .frame(minWidth: 48)

                Button {
                    onIncreaseFontSize()
                } label: {
                    Image(systemName: "textformat.size.larger")
                }

                Button("Reset") {
                    onResetFontSize()
                }
            }

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
        .buttonStyle(.bordered)
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
