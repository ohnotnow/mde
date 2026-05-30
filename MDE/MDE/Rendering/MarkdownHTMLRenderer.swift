import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Converts Markdown to an HTML fragment using cmark-gfm (the same C library that
/// sits under MarkdownUI), with the GitHub-flavoured extensions enabled. This mirrors
/// the conversion `gumdhtml` does with goldmark — parse once, emit HTML, let the
/// browser engine do the layout.
enum MarkdownHTMLConverter {
    // cmark's option flags are C `#define` macros, which don't import into Swift.
    // Re-declare the few we need. Values are stable in the cmark-gfm headers.
    private static let optDefault: Int32 = 0
    private static let optUnsafe: Int32 = 1 << 17   // allow raw inline HTML (gumdhtml uses WithUnsafe)
    private static let optSmart: Int32 = 1 << 10    // smart punctuation (gumdhtml uses Typographer)

    /// Register the GFM core extensions exactly once for the process.
    private static let registerExtensions: Void = {
        cmark_gfm_core_extensions_ensure_registered()
    }()

    static func html(from markdown: String) -> String {
        _ = registerExtensions

        let options = optDefault | optUnsafe | optSmart

        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in ["table", "strikethrough", "autolink", "tasklist"] {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        let byteCount = markdown.utf8.count
        markdown.withCString { cString in
            cmark_parser_feed(parser, cString, byteCount)
        }

        guard let documentNode = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(documentNode) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let renderedHTML = cmark_render_html(documentNode, options, extensions) else { return "" }
        defer { free(renderedHTML) }

        return String(cString: renderedHTML)
    }
}

/// Assembles a complete, self-contained HTML document around the converted body,
/// using the University of Glasgow house style borrowed from `gumdhtml`.
enum ReaderHTMLDocument {
    static func make(document: MarkdownDocument, settings: AppSettings) -> String {
        let bodyHTML = MarkdownHTMLConverter.html(from: document.bodyText)
        let bannerTitle = escape(bannerName(for: document))

        let frontMatterBlock: String
        if let frontMatter = document.frontMatterText,
           !frontMatter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            frontMatterBlock = "<pre class=\"front-matter\">\(escape(frontMatter))</pre>\n"
        } else {
            frontMatterBlock = ""
        }

        let fontSize = Int(settings.readerFontSize.rounded())
        let lineHeight = String(format: "%.2f", settings.readerLineHeight)
        let fontStack = Self.fontStack(for: settings.readerFontFamily)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(bannerTitle)</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;0,800;1,400;1,600&display=swap" rel="stylesheet">
        <style>
        \(Self.styleSheet)
        :root { --font-body: \(fontStack); }
        html { font-size: \(fontSize)px; }
        body { line-height: \(lineHeight); }
        </style>
        </head>
        <body>
        <header class="page-head">
          <div class="page-head-inner">
            <h1 class="page-heading">\(bannerTitle)</h1>
          </div>
        </header>
        <div class="page">
          <main class="page-body">
        \(frontMatterBlock)\(bodyHTML)
          </main>
        </div>
        </body>
        </html>
        """
    }

    /// The filename (without extension) reads better in the banner than the first
    /// H1, which is already shown in the body just below it.
    private static func bannerName(for document: MarkdownDocument) -> String {
        guard let url = document.fileURL else { return "Untitled" }
        return url.deletingPathExtension().lastPathComponent
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Maps the reader's font choice onto a CSS `--font-body` stack. "System Sans"
    /// is the UofG house font (Noto Sans); the rest let the reader override it.
    private static func fontStack(for family: ReaderFontFamily) -> String {
        switch family {
        case .system:
            return #""Noto Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif"#
        case .serif:
            return #"Georgia, "Times New Roman", Times, serif"#
        case .mono:
            return #"ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace"#
        case .custom(let name):
            let safe = name.replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: "\"", with: "")
            return "\"\(safe)\", -apple-system, sans-serif"
        }
    }
}

extension ReaderHTMLDocument {
    /// The University of Glasgow house style, lifted from `gumdhtml/assets/style.css`.
    /// Trimmed of the standalone-document chrome (the year footer) since this renders
    /// inside an app window, and given a `.front-matter` rule for the YAML block.
    static let styleSheet = """
    :root {
      color-scheme: light dark;
      --uofg-blue: #011451;
      --uofg-dark-blue: #005398;
      --uofg-blue-80: #344374;
      --uofg-blue-60: #677297;
      --uofg-blue-40: #99a1b9;
      --uofg-blue-20: #ccd0dc;
      --uofg-blue-10: #e6e7ee;

      --uofg-ink: #1a1a1a;
      --uofg-text: #323232;
      --uofg-muted: #666666;
      --uofg-rule: #cccccc;
      --uofg-panel: #f5f5f5;
      --uofg-panel-edge: #e6e6e6;

      --uofg-paper: #ffffff;
      --uofg-highlight: #ffdd00;
      --uofg-arrow: #c5413a;

      --font-body: "Noto Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Consolas, "Liberation Mono", monospace;

      --space-1: 4px;  --space-2: 8px;  --space-3: 12px; --space-4: 16px;
      --space-5: 20px; --space-6: 24px; --space-7: 32px; --space-8: 40px;
      --space-9: 48px; --space-10: 56px; --space-11: 64px; --space-12: 96px;

      --measure: 72ch;
    }

    * { box-sizing: border-box; }

    html { -webkit-text-size-adjust: 100%; }

    body {
      margin: 0;
      font-family: var(--font-body);
      font-weight: 400;
      color: var(--uofg-text);
      background: var(--uofg-paper);
      font-feature-settings: "kern", "liga";
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    .page {
      max-width: 80ch;
      margin: 0 auto;
      padding: 0 clamp(20px, 4vw, 48px) clamp(40px, 6vw, 80px);
    }

    /* masthead: full-bleed navy ribbon */
    .page-head { background: var(--uofg-blue); color: #fff; width: 100%; margin-bottom: var(--space-9); }
    .page-head-inner {
      max-width: 80ch; margin: 0 auto;
      padding: var(--space-6) clamp(20px, 4vw, 48px);
      min-height: 56px; display: flex; align-items: center;
    }
    .page-heading {
      font-family: var(--font-body); color: #fff;
      font-size: clamp(1.6rem, 3.4vw, 2.2rem); font-weight: 800;
      text-transform: uppercase; letter-spacing: -0.005em; line-height: 1.15;
      margin: 0; padding: 0; border: none;
    }

    .page-body { font-size: 1rem; }

    p, ul, ol, dl, blockquote, table, pre { max-width: var(--measure); }
    p { margin: 0 0 var(--space-5); }
    strong { font-weight: 700; color: var(--uofg-ink); }
    em { font-style: italic; }

    /* front-matter (YAML), shown subdued above the body */
    .front-matter {
      font-family: var(--font-mono);
      font-size: 0.85rem;
      color: var(--uofg-muted);
      background: var(--uofg-panel);
      border: 1px solid var(--uofg-panel-edge);
      padding: var(--space-4);
      margin: 0 0 var(--space-7);
      white-space: pre-wrap;
      max-width: var(--measure);
    }

    h1, h2, h3, h4, h5, h6 {
      font-family: var(--font-body); color: var(--uofg-blue);
      line-height: 1.15; margin: 0; font-feature-settings: "kern", "liga";
    }
    h1 {
      font-size: clamp(1.9rem, 3.8vw, 2.6rem); font-weight: 800;
      text-transform: uppercase; letter-spacing: -0.005em;
      margin-bottom: var(--space-8); padding-bottom: var(--space-4);
      border-bottom: 1px solid var(--uofg-rule);
    }
    h2 { font-size: clamp(1.35rem, 2.4vw, 1.55rem); font-weight: 700; margin: var(--space-10) 0 var(--space-4); }
    h3 { font-size: 1.15rem; font-weight: 700; margin: var(--space-8) 0 var(--space-3); }
    h4 { font-size: 1rem; font-weight: 700; color: var(--uofg-ink); margin: var(--space-6) 0 var(--space-2); }
    h5, h6 {
      font-size: 0.8rem; font-weight: 700; text-transform: uppercase;
      letter-spacing: 0.08em; color: var(--uofg-muted); margin: var(--space-5) 0 var(--space-2);
    }
    h1 + p { font-size: 1.1rem; color: var(--uofg-ink); line-height: 1.55; max-width: var(--measure); }

    a {
      color: var(--uofg-dark-blue); text-decoration: underline;
      text-decoration-thickness: 1px; text-underline-offset: 0.18em;
      text-decoration-color: rgba(0, 83, 152, 0.4);
      transition: text-decoration-color 160ms ease, color 160ms ease;
    }
    a:hover { text-decoration-color: var(--uofg-dark-blue); color: var(--uofg-blue); }

    /* lists with the corporate arrow accent */
    ul, ol { margin: 0 0 var(--space-5); padding: 0; }
    ul { list-style: none; padding-left: 0; }
    ul > li { position: relative; padding-left: 1.65em; margin-bottom: var(--space-3); }
    ul > li::before {
      content: "→"; position: absolute; left: 0; top: 0;
      color: var(--uofg-arrow); font-weight: 700; font-size: 1em; line-height: 1.6;
    }
    ul ul, ol ul { margin-top: var(--space-3); margin-bottom: var(--space-3); }
    ul ul > li::before { color: var(--uofg-blue-60); }
    ol { list-style: none; counter-reset: gumd-ol; padding-left: 0; }
    ol > li { position: relative; padding-left: 2em; margin-bottom: var(--space-3); counter-increment: gumd-ol; }
    ol > li::before {
      content: counter(gumd-ol) "."; position: absolute; left: 0; top: 0;
      color: var(--uofg-blue); font-weight: 700; min-width: 1.5em;
    }
    li > p { margin-bottom: var(--space-2); }
    li > p:last-child { margin-bottom: 0; }

    dl { margin: 0 0 var(--space-5); }
    dt { font-weight: 700; color: var(--uofg-blue); margin-top: var(--space-3); }
    dd { margin: 0 0 var(--space-2) 0; padding-left: var(--space-4); }

    hr { border: none; border-top: 1px solid var(--uofg-rule); margin: var(--space-9) 0; max-width: var(--measure); }

    blockquote {
      margin: var(--space-7) 0;
      padding-left: 2.6rem;
      position: relative;
      color: var(--uofg-text);
      font-style: italic;
      font-size: 1.1rem;
    }
    blockquote::before {
      content: "“";
      position: absolute;
      left: 0;
      top: -0.08em;
      font-family: Georgia, "Times New Roman", Times, serif;
      font-style: normal;
      font-weight: 700;
      font-size: 3.2rem;
      line-height: 1;
      color: var(--uofg-arrow);
    }
    blockquote p { margin-bottom: var(--space-3); }
    blockquote p:last-child { margin-bottom: 0; }

    code, pre, kbd, samp { font-family: var(--font-mono); font-size: 0.92em; }
    code { background: var(--uofg-blue-10); padding: 0.1em 0.35em; border-radius: 2px; color: var(--uofg-blue); }
    pre {
      background: var(--uofg-panel); border: 1px solid var(--uofg-panel-edge);
      padding: var(--space-4); overflow-x: auto; margin: var(--space-5) 0;
      line-height: 1.5; color: var(--uofg-ink);
    }
    pre code { background: none; padding: 0; color: inherit; font-size: 0.95em; }

    table { border-collapse: collapse; width: 100%; margin: var(--space-6) 0; font-size: 0.95rem; }
    thead th {
      text-align: left; font-weight: 700; color: #fff; background: var(--uofg-blue);
      padding: var(--space-3) var(--space-4); vertical-align: bottom;
    }
    tbody td { padding: var(--space-3) var(--space-4); border-bottom: 1px solid var(--uofg-panel-edge); vertical-align: top; }
    tbody tr:nth-child(even) { background: var(--uofg-panel); }
    tbody tr:hover { background: var(--uofg-blue-10); }

    img { max-width: 100%; height: auto; display: block; margin: var(--space-5) 0; }

    .footnotes {
      margin-top: var(--space-10); padding-top: var(--space-5);
      border-top: 1px solid var(--uofg-rule); font-size: 0.9rem; color: var(--uofg-muted);
    }
    .footnotes ol { padding-left: 0; }
    .footnotes hr { display: none; }

    input[type="checkbox"] { margin-right: 0.4em; accent-color: var(--uofg-blue); transform: translateY(1px); }
    ul > li:has(> input[type="checkbox"])::before { content: none; }
    ul > li:has(> input[type="checkbox"]) { padding-left: 0; }

    ::selection { background: var(--uofg-highlight); color: var(--uofg-blue); }

    @media (max-width: 640px) {
      .page { padding: 0 16px 32px; }
      .page-head { margin-bottom: var(--space-7); }
      .page-head-inner { padding: var(--space-4) 16px; min-height: 48px; }
      h1 { font-size: 1.7rem; }
      table { font-size: 0.88rem; }
      thead th, tbody td { padding: var(--space-2) var(--space-3); }
    }

    @media (prefers-reduced-motion: reduce) {
      * { transition: none !important; animation: none !important; }
    }

    /* Dark mode. UofG has no official dark palette, so this is a sympathetic
       invention: the same navy/coral identity flipped onto a dark surface.
       Driven entirely by the system setting via prefers-color-scheme, so it
       switches live when the user toggles appearance. */
    @media (prefers-color-scheme: dark) {
      :root {
        --uofg-blue: #8fb3e6;
        --uofg-dark-blue: #82b4f0;
        --uofg-blue-10: #242b38;
        --uofg-blue-60: #8089a0;

        --uofg-ink: #f2f4f9;
        --uofg-text: #d4d8e1;
        --uofg-muted: #9298a5;
        --uofg-rule: #363b45;
        --uofg-panel: #1e222a;
        --uofg-panel-edge: #313742;

        --uofg-paper: #15171c;
        --uofg-arrow: #e2685f;
      }
      /* --uofg-blue is now a light foreground colour, so the few places that
         used it as a dark *background* need their navy put back explicitly. */
      .page-head { background: #122a5c; }
      .page-heading { color: #ffffff; }
      thead th { background: #1a3563; color: #ffffff; }
      ::selection { color: #15171c; }
    }
    """
}
