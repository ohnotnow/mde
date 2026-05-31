import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// The reading surface. Converts the document to a self-contained HTML page and
/// hands it to a `WKWebView`, which lays out and scrolls even very long documents
/// without breaking a sweat — the whole reason we moved off the SwiftUI view tree.
struct MarkdownReaderView: View {
    let document: MarkdownDocument
    let settings: AppSettings
    let navigator: ReaderNavigator
    let onOpenFile: (URL) -> Void
    let onDropTargetingChange: (Bool) -> Void

    var body: some View {
        ReaderWebView(
            html: ReaderHTMLDocument.make(document: document, settings: settings),
            resourceDirectory: document.fileURL?.deletingLastPathComponent(),
            documentKey: document.fileURL?.path ?? "untitled",
            navigator: navigator,
            onOpenFile: onOpenFile,
            onDropTargetingChange: onDropTargetingChange
        )
        .ignoresSafeArea()
    }
}

struct ReaderWebView: NSViewRepresentable {
    let html: String
    /// The directory whose files (images) the document may reference. Served via a
    /// custom scheme rather than a file:// base URL — see `LocalResourceSchemeHandler`.
    let resourceDirectory: URL?
    /// Identifies the underlying document. When it is unchanged across an update
    /// (a quick edit, a font-size change) we preserve the scroll position; when it
    /// changes (a different file) we start at the top.
    let documentKey: String
    let navigator: ReaderNavigator
    let onOpenFile: (URL) -> Void
    let onDropTargetingChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenFile: onOpenFile)
    }

    func makeNSView(context: Context) -> DropAwareWebView {
        let configuration = WKWebViewConfiguration()

        // SECURITY: this is a viewer for Markdown files that may come from
        // untrusted sources (downloads, email, cloned repos), and the app is not
        // sandboxed. Markdown has no legitimate need to execute scripts, so we
        // forbid page-supplied JavaScript. This neutralises <script>, inline
        // event handlers (onerror=…) and javascript: URLs. Our own scroll/find
        // calls keep working: allowsContentJavaScript gates the *page's* scripts,
        // not the host's evaluateJavaScript.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        // Local images are served through a custom scheme (below) rather than a
        // file:// base URL. That means the page runs in the `mde-resource` origin
        // with *no* filesystem access at all — and images actually load, which
        // they don't reliably do from a string-loaded file:// document on macOS.
        let resourceHandler = LocalResourceSchemeHandler()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: LocalResourceSchemeHandler.scheme)
        context.coordinator.resourceHandler = resourceHandler

        let webView = DropAwareWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        webView.onDropFile = onOpenFile
        webView.onDropTargetingChange = onDropTargetingChange

        navigator.webView = webView
        // Install the remote-content blocker first; the first document load is held
        // until it's applied so nothing remote can be fetched before the block is up.
        context.coordinator.installRemoteBlocker(on: webView)
        context.coordinator.render(html: html, resourceDirectory: resourceDirectory, documentKey: documentKey, in: webView)
        return webView
    }

    func updateNSView(_ webView: DropAwareWebView, context: Context) {
        navigator.webView = webView
        webView.onDropFile = onOpenFile
        webView.onDropTargetingChange = onDropTargetingChange
        context.coordinator.render(html: html, resourceDirectory: resourceDirectory, documentKey: documentKey, in: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onOpenFile: (URL) -> Void
        var resourceHandler: LocalResourceSchemeHandler?

        private var loadedHTML: String?
        private var loadedDocumentKey: String?
        private var scrollToRestore: Double?

        private var blockerReady = false
        private var queuedLoad: (html: String, resourceDirectory: URL?, documentKey: String, webView: WKWebView)?

        init(onOpenFile: @escaping (URL) -> Void) {
            self.onOpenFile = onOpenFile
        }

        /// The document is loaded against this base, so a relative `<img src>` like
        /// `screenshot.png` becomes `mde-resource://doc/screenshot.png` and is
        /// resolved back to a real file by the scheme handler.
        static let resourceBaseURL = URL(string: "\(LocalResourceSchemeHandler.scheme)://doc/")!

        // Block every http(s)/ws(s) load inside the reader. This is what stops a
        // document — which may have come from anywhere — quietly phoning home via
        // remote <img>/<iframe>/etc. on open. Local resources use the mde-resource
        // scheme and aren't matched; outbound link *clicks* are intercepted in the
        // nav delegate and opened in the real browser. Cost: remote images won't show.
        private static let blockRemoteRules = """
        [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
         {"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}}]
        """

        func installRemoteBlocker(on webView: WKWebView) {
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "mde-block-remote",
                encodedContentRuleList: Self.blockRemoteRules
            ) { [weak self, weak webView] ruleList, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let ruleList, let webView {
                        webView.configuration.userContentController.add(ruleList)
                    }
                    self.blockerReady = true
                    if let queued = self.queuedLoad {
                        self.queuedLoad = nil
                        self.render(
                            html: queued.html,
                            resourceDirectory: queued.resourceDirectory,
                            documentKey: queued.documentKey,
                            in: queued.webView
                        )
                    }
                }
            }
        }

        func render(html: String, resourceDirectory: URL?, documentKey: String, in webView: WKWebView) {
            // Hold every load until the remote-content block is in place.
            guard blockerReady else {
                queuedLoad = (html, resourceDirectory, documentKey, webView)
                return
            }
            guard html != loadedHTML else { return }

            resourceHandler?.baseDirectory = resourceDirectory

            let sameDocument = (documentKey == loadedDocumentKey)
            loadedHTML = html
            loadedDocumentKey = documentKey

            // Reloading the same document (quick edit, zoom): keep the reader where
            // they were rather than flinging them back to the top.
            if sameDocument {
                webView.evaluateJavaScript("window.scrollY") { [weak self] value, _ in
                    self?.scrollToRestore = (value as? Double) ?? 0
                    webView.loadHTMLString(html, baseURL: Self.resourceBaseURL)
                }
            } else {
                scrollToRestore = nil
                webView.loadHTMLString(html, baseURL: Self.resourceBaseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let y = scrollToRestore {
                scrollToRestore = nil
                webView.evaluateJavaScript("window.scrollTo(0, \(y));")
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // A local file navigation here is never our own load (those use the
            // mde-resource scheme) — it's a dropped file the web view tried to open,
            // or a link to a local file. Open Markdown as a document; otherwise just
            // refuse to navigate away from the reader.
            if url.isFileURL {
                if Self.isMarkdown(url) {
                    onOpenFile(url)
                }
                decisionHandler(.cancel)
                return
            }

            // Outbound links open in the user's browser; in-page anchors stay.
            if navigationAction.navigationType == .linkActivated {
                switch url.scheme {
                case "http", "https", "mailto":
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                default:
                    break
                }
            }

            decisionHandler(.allow)
        }

        static func isMarkdown(_ url: URL) -> Bool {
            ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased())
        }
    }
}

/// A `WKWebView` that accepts a dragged-in Markdown file and opens it, rather than
/// letting the web engine navigate to it (which is what broke drag-to-open after
/// the move off SwiftUI rendering).
final class DropAwareWebView: WKWebView {
    var onDropFile: ((URL) -> Void)?
    var onDropTargetingChange: ((Bool) -> Void)?

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepts = droppedMarkdownURL(sender) != nil
        onDropTargetingChange?(accepts)
        return accepts ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMarkdownURL(sender) != nil ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargetingChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedMarkdownURL(sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropTargetingChange?(false)
        guard let url = droppedMarkdownURL(sender) else { return false }
        onDropFile?(url)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onDropTargetingChange?(false)
    }

    private func droppedMarkdownURL(_ sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first { Self.markdownExtensions.contains($0.pathExtension.lowercased()) }
    }
}

/// Serves the document's sibling files (images) to the web view over a private
/// scheme, so the rendered page never has to run in a file:// origin. The handler
/// only ever reads files relative to the current document's directory.
final class LocalResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mde-resource"

    /// The directory the current document lives in. Relative image paths resolve
    /// against this. `nil` for an unsaved/empty document.
    var baseDirectory: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = resolve(requestURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func resolve(_ url: URL) -> URL? {
        guard let baseDirectory else { return nil }
        // `url.path` is percent-decoded, e.g. "/images/diagram.png".
        let relativePath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard !relativePath.isEmpty else { return nil }
        return baseDirectory.appendingPathComponent(relativePath)
    }
}
