import AppKit
import SwiftUI

struct WorkspaceView: View {
    @Binding var document: MarkdownDocument
    @Binding var settings: AppSettings

    let onOpenDroppedFile: (URL) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        readerPane
        .frame(minWidth: 920, minHeight: 640)
        .background(WindowConfigurationView(document: document))
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

    private var readerPane: some View {
        MarkdownReaderView(document: document, settings: settings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WindowConfigurationView: NSViewRepresentable {
    let document: MarkdownDocument

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            window.title = document.displayName
            window.representedURL = document.fileURL
        }
    }
}
