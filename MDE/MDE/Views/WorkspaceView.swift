import AppKit
import SwiftUI

struct WorkspaceView: View {
    @Binding var document: MarkdownDocument
    @Binding var settings: AppSettings

    let quickEditSession: QuickEditSession?
    let onQuickEditExit: (Int32?) -> Void
    let onOpenDroppedFile: (URL) -> Void

    @StateObject private var navigator = ReaderNavigator()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            readerPane

            if let session = quickEditSession {
                Divider()
                QuickEditPane(session: session, onExit: onQuickEditExit)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: quickEditSession?.id)
        .frame(minWidth: 920, minHeight: 640)
        .background(WindowConfigurationView(document: document))
        .focusedSceneValue(\.readerNavigator, navigator)
        .dropDestination(for: URL.self) { items, _ in
            guard let url = items.first else {
                return false
            }

            onOpenDroppedFile(url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay(alignment: .topTrailing) {
            if navigator.isFindBarVisible {
                FindBarView(navigator: navigator)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
            }
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
        MarkdownReaderView(
            document: document,
            settings: settings,
            navigator: navigator,
            onOpenFile: onOpenDroppedFile,
            onDropTargetingChange: { isDropTargeted = $0 }
        )
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
