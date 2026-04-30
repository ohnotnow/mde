import AppKit
import MarkdownUI
import SwiftUI

struct MarkdownUIRenderer: MarkdownRenderer {
    let id = "markdownui-renderer"
    let displayName = "MarkdownUI"

    func makeRenderedView(document: MarkdownDocument, settings: AppSettings) -> AnyView {
        AnyView(
            MarkdownUIReader(document: document, settings: settings)
        )
    }
}

private struct MarkdownUIReader: View {
    let document: MarkdownDocument
    let settings: AppSettings

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            if document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyState
            } else {
                ScrollView {
                    let markdown = Markdown(document.text)
                        .markdownTheme(.mde)
                        .markdownTextStyle {
                            FontSize(settings.readerFontSize)
                        }
                        .frame(maxWidth: contentMaxWidth, alignment: .leading)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if let highlighter = NordSyntaxHighlighter.shared {
                        markdown.markdownCodeSyntaxHighlighter(highlighter)
                    } else {
                        markdown
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    private var contentMaxWidth: CGFloat {
        max(640, CGFloat(settings.readerFontSize) * 38)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing to render yet.")
                .font(.title3.weight(.semibold))

            Text("Open a Markdown document from the File menu, drop one onto the window, or use Open Recent.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(44)
    }
}

extension Theme {
    static let mde: Theme = .docC
        .heading1 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.05))
                .markdownMargin(top: .em(0.6), bottom: .em(0.4))
                .markdownTextStyle {
                    FontWeight(.heavy)
                    FontSize(.em(2.4))
                }
        }
        .heading2 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.07))
                .markdownMargin(top: .em(1.6), bottom: .em(0.3))
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.7))
                }
        }
        .heading3 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.09))
                .markdownMargin(top: .em(1.4), bottom: .em(0.2))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.35))
                }
        }
        .heading4 { configuration in
            configuration.label
                .markdownMargin(top: .em(1.2), bottom: .em(0.1))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.15))
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.4))
                .markdownMargin(top: .em(0.9), bottom: .zero)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.4))
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 16)
                .padding(.vertical, 4)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3)
                }
                .markdownMargin(top: .em(0.9), bottom: .em(0.3))
                .markdownTextStyle {
                    ForegroundColor(.secondary)
                }
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.92))
            BackgroundColor(.secondary.opacity(0.18))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .relativeLineSpacing(.em(0.25))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.95))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .background(Color.nordPolarNight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .markdownMargin(top: .em(0.9), bottom: .em(0.3))
        }
}

private extension Color {
    static let nordPolarNight = Color(red: 46.0 / 255.0, green: 52.0 / 255.0, blue: 64.0 / 255.0)
}
