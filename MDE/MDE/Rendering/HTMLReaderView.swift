import AppKit
import SwiftUI
import WebKit

/// The reading surface. Converts the document to a self-contained HTML page and
/// hands it to a `WKWebView`, which lays out and scrolls even very long documents
/// without breaking a sweat — the whole reason we moved off the SwiftUI view tree.
struct MarkdownReaderView: View {
    let document: MarkdownDocument
    let settings: AppSettings
    let navigator: ReaderNavigator

    var body: some View {
        ReaderWebView(
            html: ReaderHTMLDocument.make(document: document, settings: settings),
            baseURL: document.fileURL?.deletingLastPathComponent(),
            documentKey: document.fileURL?.path ?? "untitled",
            navigator: navigator
        )
        .ignoresSafeArea()
    }
}

struct ReaderWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    /// Identifies the underlying document. When it is unchanged across an update
    /// (a quick edit, a font-size change) we preserve the scroll position; when it
    /// changes (a different file) we start at the top.
    let documentKey: String
    let navigator: ReaderNavigator

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // SECURITY: this is a viewer for Markdown files that may come from
        // untrusted sources (downloads, email, cloned repos), and the app is not
        // sandboxed. Markdown has no legitimate need to execute scripts, so we
        // forbid page-supplied JavaScript. This neutralises <script>, inline
        // event handlers (onerror=…) and javascript: URLs — which is what closes
        // the read-local-file-and-exfiltrate path that the file:// origin below
        // would otherwise open. Our own scroll/find calls keep working:
        // allowsContentJavaScript gates the *page's* scripts, not the host's
        // evaluateJavaScript.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        // Relative <img> tags need to load sibling files. WebKit blocks file
        // subresources by default; this lifts that. With page JavaScript disabled
        // above, a malicious document can no longer read those files and send
        // their contents anywhere, so this is acceptable residual surface.
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        navigator.webView = webView
        // Install the remote-content blocker first; the first document load is held
        // until it's applied so nothing remote can be fetched before the block is up.
        context.coordinator.installRemoteBlocker(on: webView)
        context.coordinator.render(html: html, baseURL: baseURL, documentKey: documentKey, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        navigator.webView = webView
        context.coordinator.render(html: html, baseURL: baseURL, documentKey: documentKey, in: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadedHTML: String?
        private var loadedDocumentKey: String?
        private var scrollToRestore: Double?

        private var blockerReady = false
        private var queuedLoad: (html: String, baseURL: URL?, documentKey: String, webView: WKWebView)?

        // Block every http(s)/ws(s) load inside the reader. This is what stops a
        // document — which may have come from anywhere — quietly phoning home via
        // remote <img>/<iframe>/etc. on open. Local file: resources and our own
        // HTML aren't matched, so they load normally; outbound link *clicks* are
        // intercepted in the nav delegate and opened in the real browser, so they
        // never become loads the rule sees. Cost: remote images/badges won't show.
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
                            baseURL: queued.baseURL,
                            documentKey: queued.documentKey,
                            in: queued.webView
                        )
                    }
                }
            }
        }

        func render(html: String, baseURL: URL?, documentKey: String, in webView: WKWebView) {
            // Hold every load until the remote-content block is in place.
            guard blockerReady else {
                queuedLoad = (html, baseURL, documentKey, webView)
                return
            }
            guard html != loadedHTML else { return }

            let sameDocument = (documentKey == loadedDocumentKey)
            loadedHTML = html
            loadedDocumentKey = documentKey

            // Reloading the same document (quick edit, zoom): keep the reader where
            // they were rather than flinging them back to the top.
            if sameDocument {
                webView.evaluateJavaScript("window.scrollY") { [weak self] value, _ in
                    self?.scrollToRestore = (value as? Double) ?? 0
                    webView.loadHTMLString(html, baseURL: baseURL)
                }
            } else {
                scrollToRestore = nil
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let y = scrollToRestore {
                scrollToRestore = nil
                webView.evaluateJavaScript("window.scrollTo(0, \(y));")
            }
        }

        // Open outbound links in the user's browser; keep in-page anchors inside.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            switch url.scheme {
            case "http", "https", "mailto":
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            default:
                decisionHandler(.allow)
            }
        }
    }
}
