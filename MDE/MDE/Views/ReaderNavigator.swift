import AppKit
import SwiftUI

@MainActor
final class ReaderNavigator: ObservableObject {
    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var matchSummary: MatchSummary?
    @Published private(set) var focusRequest: Int = 0

    var sourceText: String = ""

    weak var scrollView: NSScrollView?

    private var matchOffsets: [Int] = []
    private var matchedQuery: String = ""
    private var currentMatchIndex: Int = 0

    struct MatchSummary: Equatable {
        let total: Int
        let current: Int
    }

    func showFindBar() {
        isFindBarVisible = true
        focusRequest &+= 1
    }

    func hideFindBar() {
        isFindBarVisible = false
        findQuery = ""
        resetMatches()
    }

    func resetMatches() {
        matchOffsets = []
        matchedQuery = ""
        currentMatchIndex = 0
        matchSummary = nil
    }

    func scrollToTop() {
        guard let scrollView else { return }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func scrollToBottom() {
        guard let scrollView, let docView = scrollView.documentView else { return }
        let target = max(0, docView.frame.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func pageDown() {
        guard let scrollView, let docView = scrollView.documentView else { return }
        let visible = scrollView.contentView.bounds
        let pageStep = max(visible.height - 36, visible.height * 0.85)
        let maxY = max(0, docView.frame.height - visible.height)
        let target = min(maxY, visible.origin.y + pageStep)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func pageUp() {
        guard let scrollView else { return }
        let visible = scrollView.contentView.bounds
        let pageStep = max(visible.height - 36, visible.height * 0.85)
        let target = max(0, visible.origin.y - pageStep)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func lineDown() {
        guard let scrollView, let docView = scrollView.documentView else { return }
        let visible = scrollView.contentView.bounds
        let maxY = max(0, docView.frame.height - visible.height)
        let target = min(maxY, visible.origin.y + lineStep)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func lineUp() {
        guard let scrollView else { return }
        let visible = scrollView.contentView.bounds
        let target = max(0, visible.origin.y - lineStep)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private var lineStep: CGFloat { 28 }

    func performFind(forward: Bool) {
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if matchedQuery != trimmed {
            recomputeMatches(for: trimmed)
            currentMatchIndex = forward ? -1 : matchOffsets.count
        }

        guard !matchOffsets.isEmpty else {
            matchSummary = MatchSummary(total: 0, current: 0)
            return
        }

        if forward {
            currentMatchIndex = (currentMatchIndex + 1) % matchOffsets.count
        } else {
            currentMatchIndex = (currentMatchIndex - 1 + matchOffsets.count) % matchOffsets.count
        }

        let offset = matchOffsets[currentMatchIndex]
        let total = max(sourceText.count, 1)
        scrollToFraction(CGFloat(offset) / CGFloat(total))
        matchSummary = MatchSummary(total: matchOffsets.count, current: currentMatchIndex + 1)
    }

    private func scrollToFraction(_ fraction: CGFloat) {
        guard let scrollView, let docView = scrollView.documentView else { return }
        let maxY = max(0, docView.frame.height - scrollView.contentView.bounds.height)
        let clamped = min(max(fraction, 0), 1)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * clamped))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func recomputeMatches(for query: String) {
        matchedQuery = query
        matchOffsets = []
        guard !query.isEmpty, !sourceText.isEmpty else { return }

        let lowerSource = sourceText.lowercased()
        let lowerQuery = query.lowercased()
        var search = lowerSource.startIndex..<lowerSource.endIndex
        while let range = lowerSource.range(of: lowerQuery, options: [], range: search) {
            let offset = lowerSource.distance(from: lowerSource.startIndex, to: range.lowerBound)
            matchOffsets.append(offset)
            search = range.upperBound..<lowerSource.endIndex
        }
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

struct HostingScrollView<Content: View>: NSViewRepresentable {
    @ObservedObject var navigator: ReaderNavigator
    let content: Content

    init(navigator: ReaderNavigator, @ViewBuilder content: () -> Content) {
        self.navigator = navigator
        self.content = content()
    }

    func makeNSView(context: Context) -> KeyAwareScrollView {
        let scrollView = KeyAwareScrollView()
        scrollView.navigator = navigator
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: clipView.topAnchor),
            hosting.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])

        navigator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: KeyAwareScrollView, context: Context) {
        scrollView.navigator = navigator
        navigator.scrollView = scrollView
        if let hosting = scrollView.documentView as? NSHostingView<Content> {
            hosting.rootView = content
        }
    }
}

final class KeyAwareScrollView: NSScrollView {
    weak var navigator: ReaderNavigator?
    private var keyMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let existing = keyMonitor {
            NSEvent.removeMonitor(existing)
            keyMonitor = nil
        }

        guard window != nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let navigator else { return false }
        guard let window = self.window, event.window === window else { return false }
        if isTextInputFocused(in: window) { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let bare = modifiers.subtracting([.numericPad, .function, .capsLock])
        let chars = event.charactersIgnoringModifiers ?? ""

        if bare.isEmpty || bare == .shift {
            if chars == " " {
                if bare.contains(.shift) {
                    navigator.pageUp()
                } else {
                    navigator.pageDown()
                }
                return true
            }

            if chars == "/" && bare.isEmpty {
                navigator.showFindBar()
                return true
            }
        }

        if bare.isEmpty {
            switch event.keyCode {
            case 126:
                navigator.lineUp()
                return true
            case 125:
                navigator.lineDown()
                return true
            default:
                break
            }
        }

        return false
    }

    private func isTextInputFocused(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }
        if responder is NSText { return true }
        if responder is NSTextView { return true }
        if let view = responder as? NSView, !view.isDescendant(of: self) {
            return true
        }
        return false
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
                .onChange(of: navigator.findQuery) { _, _ in
                    navigator.resetMatches()
                }

            if let summary = navigator.matchSummary, !navigator.findQuery.isEmpty {
                Text(summary.total == 0 ? "No matches" : "\(summary.current) of \(summary.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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
