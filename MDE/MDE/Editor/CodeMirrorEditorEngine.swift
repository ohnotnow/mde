import MarkdownEditor
import WebKit
import SwiftUI

struct CodeMirrorEditorEngine: EditorEngine {
    let id = "codemirror"
    let displayName = "MarkdownEditor"
    let capabilities: EditorCapabilities = [
        .syntaxHighlighting,
        .inlineImages,
        .richTextFormatting,
        .liveInlineRendering
    ]

    func makeEditorView(
        document: Binding<MarkdownDocument>,
        settings: AppSettings
    ) -> AnyView {
        AnyView(
            StyledEditorWebView(
                text: textBinding(for: document),
                configuration: EditorConfiguration(
                    fontSize: settings.editorFontSize,
                    fontFamily: settings.editorFontFamily.cssValue,
                    lineHeight: settings.editorLineHeight,
                    showLineNumbers: settings.showLineNumbers,
                    wrapLines: settings.wrapLines,
                    renderMermaid: false,
                    renderMath: true,
                    renderImages: true,
                    hideSyntax: settings.hideSyntax
                ),
                customCSS: customCSS(for: settings)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    func apply(_ command: EditorCommand, to document: Binding<MarkdownDocument>) {
        switch command {
        case .bold:
            append(marker: "**", to: document)
        case .italic:
            append(marker: "_", to: document)
        }
    }

    func customCSS(for settings: AppSettings) -> String? {
        let horizontalPadding = settings.showLineNumbers ? 10 : 8
        let gutterPadding = settings.showLineNumbers ? 10 : 8

        return """
        .cm-content {
          padding-top: 14px !important;
          padding-right: 16px !important;
          padding-bottom: 18px !important;
          padding-left: \(horizontalPadding)px !important;
        }
        .cm-gutter.cm-lineNumbers .cm-gutterElement {
          padding-left: \(gutterPadding)px !important;
          padding-right: 8px !important;
        }
        .mde-frontmatter-line {
          opacity: 0.56 !important;
          font-size: 0.88em !important;
          font-weight: 480 !important;
        }
        .mde-frontmatter-fence {
          opacity: 0.3 !important;
        }
        .mde-heading-line {
          text-indent: calc(var(--mde-heading-offset, 0.8ch) * -1) !important;
          padding-left: var(--mde-heading-offset, 0.8ch) !important;
        }
        """
    }

    private func textBinding(for document: Binding<MarkdownDocument>) -> Binding<String> {
        Binding(
            get: { document.wrappedValue.text },
            set: { newValue in
                var updated = document.wrappedValue
                updated.text = newValue
                updated.isDirty = true
                document.wrappedValue = updated
            }
        )
    }

    private func append(marker: String, to document: Binding<MarkdownDocument>) {
        var updated = document.wrappedValue
        updated.text += "\(marker)\(marker)"
        updated.isDirty = true
        document.wrappedValue = updated
    }
}

struct StyledEditorWebView: NSViewRepresentable {
    @Binding var text: String

    let configuration: EditorConfiguration
    let customCSS: String?

    @Environment(\.colorScheme) private var colorScheme

    init(
        text: Binding<String>,
        configuration: EditorConfiguration,
        customCSS: String?
    ) {
        self._text = text
        self.configuration = configuration
        self.customCSS = customCSS
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all

        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        let coordinator = context.coordinator
        coordinator.configure(
            webView: webView,
            text: _text,
            configuration: configuration,
            theme: currentTheme,
            customCSS: customCSS
        )

        loadEditor(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            text: _text,
            configuration: configuration,
            theme: currentTheme,
            customCSS: customCSS
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.bridge.cleanup()
    }

    private var currentTheme: EditorTheme {
        colorScheme == .dark ? .dark : .light
    }

    private func loadEditor(in webView: WKWebView) {
        guard
            let resourceBundle = Bundle.main.url(forResource: "MarkdownEditor_MarkdownEditor", withExtension: "bundle")
                .flatMap(Bundle.init(url:)),
            let htmlURL = resourceBundle.url(forResource: "editor", withExtension: "html")
        else {
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    @MainActor
    final class Coordinator: NSObject, EditorBridgeDelegate {
        let bridge = EditorBridge()

        private weak var webView: WKWebView?
        private var textBinding: Binding<String>?
        private var initialContent = ""
        private var lastKnownContent = ""
        private var currentTheme: EditorTheme = .light
        private var currentConfiguration: EditorConfiguration = .default
        private var currentCustomCSS: String?
        private var isUpdatingBinding = false

        func configure(
            webView: WKWebView,
            text: Binding<String>,
            configuration: EditorConfiguration,
            theme: EditorTheme,
            customCSS: String?
        ) {
            self.webView = webView
            self.textBinding = text
            self.initialContent = text.wrappedValue
            self.currentConfiguration = configuration
            self.currentTheme = theme
            self.currentCustomCSS = customCSS

            bridge.configure(with: webView)
            bridge.delegate = self
        }

        func update(
            text: Binding<String>,
            configuration: EditorConfiguration,
            theme: EditorTheme,
            customCSS: String?
        ) {
            self.textBinding = text
            self.currentCustomCSS = customCSS

            if currentTheme != theme {
                currentTheme = theme
                Task { @MainActor in
                    await bridge.setTheme(theme)
                    await applyCustomPresentation()
                }
            }

            if currentConfiguration != configuration {
                currentConfiguration = configuration
                Task { @MainActor in
                    await bridge.updateConfiguration(configuration)
                    await applyCustomPresentation()
                }
            }

            if text.wrappedValue != lastKnownContent && !isUpdatingBinding {
                lastKnownContent = text.wrappedValue
                Task { @MainActor in
                    try? await bridge.setContent(text.wrappedValue)
                    await applyCustomPresentation()
                }
            }
        }

        func editorDidChangeContent(_ content: String) {
            guard let textBinding else {
                return
            }

            isUpdatingBinding = true
            lastKnownContent = content
            textBinding.wrappedValue = content
            isUpdatingBinding = false

            Task { @MainActor in
                await applyCustomPresentation()
            }
        }

        func editorDidBecomeReady() {
            Task { @MainActor in
                await bridge.setTheme(currentTheme)
                await bridge.updateConfiguration(currentConfiguration)

                if !initialContent.isEmpty {
                    try? await bridge.setContent(initialContent)
                    lastKnownContent = initialContent
                }

                await applyCustomPresentation()
            }
        }

        func editorDidChangeSelection(_ selection: EditorSelection) {}
        func editorDidFocus() {}
        func editorDidBlur() {}

        private func applyCustomPresentation() async {
            guard let webView, bridge.isReady else {
                return
            }

            let css = currentCustomCSS ?? ""
            let script = """
            (function() {
              const styleId = "mde-custom-editor-style";
              let style = document.getElementById(styleId);
              if (!style) {
                style = document.createElement("style");
                style.id = styleId;
                document.head.appendChild(style);
              }
              style.textContent = \(css.javaScriptQuoted);

              const content = document.querySelector(".cm-content");
              if (!content) return;

              const applyPresentation = () => {
                content.querySelectorAll(".mde-frontmatter-line, .mde-frontmatter-fence, .mde-heading-line")
                  .forEach((line) => {
                    line.classList.remove("mde-frontmatter-line", "mde-frontmatter-fence", "mde-heading-line");
                    line.style.removeProperty("--mde-heading-offset");
                  });

                const lines = Array.from(content.querySelectorAll(".cm-line"));
                if (lines.length === 0) return;

                let inFrontmatter = false;

                for (let index = 0; index < lines.length; index += 1) {
                  const line = lines[index];
                  const rawText = line.textContent || "";
                  const trimmedText = rawText.trim();
                  const headingMatch = rawText.match(/^\\s{0,3}(#{1,6})\\s+/);

                  if (headingMatch) {
                    const markerWidth = headingMatch[1].length + 1;
                    line.classList.add("mde-heading-line");
                    line.style.setProperty("--mde-heading-offset", `${markerWidth}ch`);
                  }

                  if (index === 0 && trimmedText === "---") {
                    inFrontmatter = true;
                    line.classList.add("mde-frontmatter-line", "mde-frontmatter-fence");
                    continue;
                  }

                  if (!inFrontmatter) {
                    continue;
                  }

                  line.classList.add("mde-frontmatter-line");
                  if (trimmedText === "---" || trimmedText === "...") {
                    line.classList.add("mde-frontmatter-fence");
                    inFrontmatter = false;
                  }
                }
              };

              if (!content.__mdePresentationObserver) {
                const observer = new MutationObserver(() => {
                  window.requestAnimationFrame(applyPresentation);
                });
                observer.observe(content, {
                  childList: true,
                  subtree: true,
                  characterData: true
                });
                content.__mdePresentationObserver = observer;
              }

              applyPresentation();
            })();
            """

            _ = try? await webView.evaluateJavaScript(script)
        }
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
