import AppKit
import SwiftUI
import WebKit

/// Drives reader navigation against the `WKWebView`: find-in-document (using the
/// web view's native, properly-highlighted find) and jump-to-top/bottom.
@MainActor
final class ReaderNavigator: ObservableObject {
    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var lastFindFailed: Bool = false
    @Published private(set) var focusRequest: Int = 0

    weak var webView: WKWebView?

    func showFindBar() {
        isFindBarVisible = true
        focusRequest &+= 1
    }

    func hideFindBar() {
        isFindBarVisible = false
        findQuery = ""
        lastFindFailed = false
        clearSelection()
    }

    func scrollToTop() {
        webView?.evaluateJavaScript("window.scrollTo(0, 0);")
    }

    func scrollToBottom() {
        webView?.evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight);")
    }

    func performFind(forward: Bool) {
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let webView else {
            lastFindFailed = false
            return
        }

        let configuration = WKFindConfiguration()
        configuration.backwards = !forward
        configuration.caseSensitive = false
        configuration.wraps = true

        webView.find(trimmed, configuration: configuration) { [weak self] result in
            Task { @MainActor in
                self?.lastFindFailed = !result.matchFound
            }
        }
    }

    private func clearSelection() {
        webView?.evaluateJavaScript("window.getSelection()?.removeAllRanges();")
    }
}

private struct ReaderNavigatorFocusedValueKey: FocusedValueKey {
    typealias Value = ReaderNavigator
}

extension FocusedValues {
    var readerNavigator: ReaderNavigator? {
        get { self[ReaderNavigatorFocusedValueKey.self] }
        set { self[ReaderNavigatorFocusedValueKey.self] = newValue }
    }
}

struct FindBarView: View {
    @ObservedObject var navigator: ReaderNavigator
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find", text: $navigator.findQuery)
                .textFieldStyle(.plain)
                .frame(minWidth: 180, maxWidth: 260)
                .focused($fieldFocused)
                .onSubmit {
                    navigator.performFind(forward: true)
                }

            if navigator.lastFindFailed, !navigator.findQuery.isEmpty {
                Text("Not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                navigator.performFind(forward: false)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(navigator.findQuery.isEmpty)
            .help("Previous match (⇧⌘G)")

            Button {
                navigator.performFind(forward: true)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(navigator.findQuery.isEmpty)
            .help("Next match (⌘G)")

            Button {
                navigator.hideFindBar()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.25))
        }
        .shadow(radius: 6, y: 2)
        .onAppear { fieldFocused = true }
        .onChange(of: navigator.focusRequest) { _, _ in
            fieldFocused = true
        }
    }
}
