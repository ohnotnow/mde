import AppKit
import SwiftUI

struct NativeMarkdownRenderer: MarkdownRenderer {
    let id = "native-markdown-renderer"
    let displayName = "Native Renderer"

    func makeRenderedView(document: MarkdownDocument, settings: AppSettings) -> AnyView {
        AnyView(
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                    .ignoresSafeArea()

                if document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptyState
                } else {
                    MarkdownTextView(
                        markdown: document.text,
                        settings: settings
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing to render yet.")
                .font(.title3.weight(.semibold))

            Text("Open a Markdown document from the File menu, drop one onto the window, or use Open Recent.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    let markdown: String
    let settings: AppSettings

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 44, left: 0, bottom: 44, right: 0)

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 44, height: 40)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = false
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let rendered = StyledMarkdownDocument(markdown: markdown, settings: settings)
        if rendered.attributedString.length == 0 && markdown.isEmpty == false {
            textView.string = markdown
        } else {
            textView.textStorage?.setAttributedString(rendered.attributedString)
        }

        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
    }
}

private struct StyledMarkdownDocument {
    let string: String
    let attributedString: NSAttributedString

    init(markdown: String, settings: AppSettings) {
        do {
            let parsed = try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full
                )
            )

            self.string = String(parsed.characters)
            let output = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
            let fullRange = NSRange(location: 0, length: output.length)

            output.addAttributes(
                [
                    .font: Self.font(family: settings.readerFontFamily, size: settings.readerFontSize),
                    .foregroundColor: NSColor.labelColor.withAlphaComponent(0.9),
                    .paragraphStyle: Self.baseParagraphStyle(settings: settings)
                ],
                range: fullRange
            )

            let runs = parsed.runs.map {
                StyledRun(
                    range: $0.range,
                    nsRange: NSRange($0.range, in: parsed),
                    presentationIntent: $0.presentationIntent,
                    inlinePresentationIntent: $0.inlinePresentationIntent,
                    link: $0.link
                )
            }

            for run in runs where run.nsRange.length > 0 {
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: Self.font(for: run, settings: settings),
                    .foregroundColor: Self.foregroundColor(for: run),
                    .paragraphStyle: Self.paragraphStyle(for: run, settings: settings)
                ]

                if let backgroundColor = Self.backgroundColor(for: run) {
                    attributes[.backgroundColor] = backgroundColor
                }

                if run.link != nil {
                    attributes[.foregroundColor] = NSColor.linkColor
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }

                output.addAttributes(attributes, range: run.nsRange)
            }

            Self.styleFrontMatter(in: output, source: string, settings: settings)
            self.attributedString = output
        } catch {
            self.string = markdown
            self.attributedString = NSAttributedString(
                string: markdown,
                attributes: [
                    .font: Self.font(family: settings.readerFontFamily, size: settings.readerFontSize),
                    .foregroundColor: NSColor.labelColor.withAlphaComponent(0.9),
                    .paragraphStyle: Self.baseParagraphStyle(settings: settings)
                ]
            )
        }
    }

    private static func font(for run: StyledRun, settings: AppSettings) -> NSFont {
        if run.isCodeBlock || run.isInlineCode {
            return font(family: .mono, size: settings.readerFontSize * 0.92)
        }

        if let level = run.headerLevel {
            return font(
                family: settings.readerFontFamily,
                size: headingSize(for: level, baseSize: settings.readerFontSize),
                weight: .semibold
            )
        }

        if run.isStrong && run.isEmphasized {
            return italicized(font(family: settings.readerFontFamily, size: settings.readerFontSize, weight: .semibold))
        }

        if run.isStrong {
            return font(family: settings.readerFontFamily, size: settings.readerFontSize, weight: .semibold)
        }

        if run.isEmphasized {
            return italicized(font(family: settings.readerFontFamily, size: settings.readerFontSize))
        }

        return font(family: settings.readerFontFamily, size: settings.readerFontSize)
    }

    private static func paragraphStyle(for run: StyledRun, settings: AppSettings) -> NSParagraphStyle {
        let style = baseParagraphStyle(settings: settings).mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()

        if let level = run.headerLevel {
            style.paragraphSpacingBefore = level == 1 ? 10 : 6
            style.paragraphSpacing = level <= 2 ? 14 : 10
            return style
        }

        if run.isBlockQuote {
            style.headIndent = 22
            style.firstLineHeadIndent = 22
            style.paragraphSpacing = 14
            return style
        }

        if run.isCodeBlock {
            style.headIndent = 16
            style.firstLineHeadIndent = 16
            style.paragraphSpacingBefore = 6
            style.paragraphSpacing = 16
            return style
        }

        style.paragraphSpacing = 12
        return style
    }

    private static func baseParagraphStyle(settings: AppSettings) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = max(settings.readerLineHeight - 1.0, 0.0) * settings.readerFontSize * 0.5
        style.paragraphSpacing = 12
        style.allowsDefaultTighteningForTruncation = false
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private static func foregroundColor(for run: StyledRun) -> NSColor {
        if run.isBlockQuote {
            return NSColor.labelColor.withAlphaComponent(0.68)
        }

        if run.isCodeBlock || run.isInlineCode {
            return NSColor.labelColor.withAlphaComponent(0.92)
        }

        if run.headerLevel != nil {
            return NSColor.labelColor.withAlphaComponent(0.99)
        }

        return NSColor.labelColor.withAlphaComponent(0.9)
    }

    private static func backgroundColor(for run: StyledRun) -> NSColor? {
        if run.isCodeBlock {
            return NSColor.controlBackgroundColor.withAlphaComponent(0.9)
        }

        if run.isInlineCode {
            return NSColor.controlBackgroundColor.withAlphaComponent(0.82)
        }

        return nil
    }

    private static func font(
        family: ReaderFontFamily,
        size: Double,
        weight: NSFont.Weight = .regular
    ) -> NSFont {
        switch family {
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return NSFont(descriptor: descriptor, size: size) ?? base
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    private static func italicized(_ font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }

    private static func headingSize(for level: Int, baseSize: Double) -> Double {
        switch level {
        case 1:
            return baseSize * 1.9
        case 2:
            return baseSize * 1.55
        case 3:
            return baseSize * 1.28
        case 4:
            return baseSize * 1.14
        case 5:
            return baseSize * 1.04
        default:
            return baseSize
        }
    }

    private static func styleFrontMatter(
        in output: NSMutableAttributedString,
        source: String,
        settings: AppSettings
    ) {
        guard source.hasPrefix("---\n"),
              let closingRange = source.range(of: "\n---\n")
        else {
            return
        }

        let endIndex = closingRange.upperBound
        let nsRange = NSRange(source.startIndex..<endIndex, in: source)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = max(settings.readerLineHeight - 1.0, 0.0) * settings.readerFontSize * 0.35
        style.paragraphSpacing = 12

        output.addAttributes(
            [
                .font: font(family: .mono, size: settings.readerFontSize * 0.82),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style
            ],
            range: nsRange
        )
    }
}

private struct StyledRun {
    let range: Range<AttributedString.Index>
    let nsRange: NSRange
    let presentationIntent: PresentationIntent?
    let inlinePresentationIntent: InlinePresentationIntent?
    let link: URL?

    var isBlockQuote: Bool {
        presentationIntent?.components.contains { "\($0.kind)" == "blockQuote" } == true
    }

    var isCodeBlock: Bool {
        presentationIntent?.components.contains { "\($0.kind)".hasPrefix("codeBlock") } == true
    }

    var headerLevel: Int? {
        guard let kind = presentationIntent?.components
            .map({ "\($0.kind)" })
            .first(where: { $0.hasPrefix("header ") })
        else {
            return nil
        }

        return Int(kind.replacingOccurrences(of: "header ", with: ""))
    }

    var inlineRawValue: Int {
        Int(inlinePresentationIntent?.rawValue ?? 0)
    }

    var isEmphasized: Bool {
        inlineRawValue & 1 != 0
    }

    var isStrong: Bool {
        inlineRawValue & 2 != 0
    }

    var isInlineCode: Bool {
        inlineRawValue & 4 != 0
    }
}
