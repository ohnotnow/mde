import AppKit
import MarkdownUI
import SwiftUI

struct MarkdownReaderView: View {
    let document: MarkdownDocument
    let settings: AppSettings

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            let body = document.bodyText
            let frontMatter = document.frontMatterText
            let bodyIsEmpty = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if frontMatter == nil && bodyIsEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let frontMatter {
                            frontMatterView(frontMatter)
                        }

                        if !bodyIsEmpty {
                            markdownView(for: body)
                        }
                    }
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    @ViewBuilder
    private func markdownView(for body: String) -> some View {
        let markdown = Markdown(body)
            .markdownTheme(.mde(for: settings))
            .markdownTextStyle {
                FontSize(settings.readerFontSize)
            }

        if let highlighter = NordSyntaxHighlighter.shared {
            markdown.markdownCodeSyntaxHighlighter(highlighter)
        } else {
            markdown
        }
    }

    private func frontMatterView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text)
                .font(.system(size: settings.readerFontSize * 0.9, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            DashedDivider()
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

private struct DashedDivider: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .stroke(
                Color.secondary.opacity(0.5),
                style: StrokeStyle(lineWidth: 1, dash: [3, 4])
            )
        }
        .frame(height: 1)
    }
}

extension Theme {
    static func mde(for settings: AppSettings) -> Theme {
        let bodyFamily = settings.readerFontFamily.markdownUIFamily
        let extraLineSpacing = max(0, settings.readerLineHeight - 1.0)

        return Theme.docC
            .text {
                ForegroundColor(.primary)
                FontFamily(bodyFamily)
            }
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
                .relativeLineSpacing(.em(extraLineSpacing))
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
}

extension ReaderFontFamily {
    var markdownUIFamily: FontProperties.Family {
        switch self {
        case .system:
            return .system(.default)
        case .serif:
            return .system(.serif)
        case .mono:
            return .system(.monospaced)
        case .custom(let name):
            return .custom(name)
        }
    }
}

private extension Color {
    static let nordPolarNight = Color(red: 46.0 / 255.0, green: 52.0 / 255.0, blue: 64.0 / 255.0)
}
