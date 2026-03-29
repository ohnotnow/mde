import AppKit
import SwiftUI
import WebKit

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
        ZStack {
            editorEngine.makeEditorView(document: $document, settings: settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let customCSS = editorEngine.customCSS(for: settings) {
                WebViewStyleOverlay(css: customCSS)
            }

            FileDropOverlay(
                onDrop: onOpenDroppedFile,
                onTargetChange: { targeted in
                    isDropTargeted = targeted
                }
            )
        }
    }

    private var previewPane: some View {
        previewEngine.makePreviewView(document: document, settings: settings)
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var documentTitle: String {
        document.isDirty ? "\(document.displayName) •" : document.displayName
    }
}

struct WebViewStyleOverlay: NSViewRepresentable {
    let css: String

    func makeNSView(context: Context) -> WebViewStyleInjectionView {
        let view = WebViewStyleInjectionView()
        view.css = css
        return view
    }

    func updateNSView(_ nsView: WebViewStyleInjectionView, context: Context) {
        nsView.css = css
    }
}

final class WebViewStyleInjectionView: NSView {
    var css = "" {
        didSet {
            scheduleInjection()
        }
    }

    private let styleElementID = "mde-custom-editor-style"
    private var pendingInjection = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleInjection()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleInjection()
    }

    override func layout() {
        super.layout()
        scheduleInjection()
    }

    private func scheduleInjection() {
        guard !pendingInjection else {
            return
        }

        pendingInjection = true
        DispatchQueue.main.async { [weak self] in
            self?.pendingInjection = false
            self?.injectCSS(retryCount: 8)
        }
    }

    private func injectCSS(retryCount: Int) {
        guard let webView = findNearbyWebView() else {
            guard retryCount > 0 else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.injectCSS(retryCount: retryCount - 1)
            }
            return
        }

        let script = """
        (function() {
          const styleId = \(styleElementID.javaScriptQuoted);
          const css = \(css.javaScriptQuoted);
          let style = document.getElementById(styleId);
          if (!style) {
            style = document.createElement('style');
            style.id = styleId;
            document.head.appendChild(style);
          }
          if (style.textContent !== css) {
            style.textContent = css;
          }
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func findNearbyWebView() -> WKWebView? {
        var currentView: NSView? = self

        while let view = currentView {
            if let webView = view.subviews.compactMap(findWebView(in:)).first {
                return webView
            }

            currentView = view.superview
        }

        return nil
    }

    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }

        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }

        return nil
    }
}

private extension String {
    var javaScriptQuoted: String {
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "\\n")

        return "\"\(escaped)\""
    }
}
