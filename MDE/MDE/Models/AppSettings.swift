import Foundation

struct AppSettings: Equatable {
    static let minimumFontSize = 10.0
    static let maximumFontSize = 72.0
    static let defaultFontSize = 18.0
    static let minimumLineHeight = 1.1
    static let maximumLineHeight = 2.2

    var editorFontSize: Double = AppSettings.defaultFontSize
    var editorFontFamily: EditorFontFamily = .sfMono
    var editorLineHeight: Double = 1.6
    var showLineNumbers: Bool = true
    var wrapLines: Bool = true
    var hideSyntax: Bool = true
    var showPreview: Bool = true

    mutating func increaseFontSize() {
        editorFontSize = min(editorFontSize + 1, Self.maximumFontSize)
    }

    mutating func decreaseFontSize() {
        editorFontSize = max(editorFontSize - 1, Self.minimumFontSize)
    }

    mutating func resetFontSize() {
        editorFontSize = Self.defaultFontSize
    }

    mutating func clampValues() {
        editorFontSize = min(max(editorFontSize, Self.minimumFontSize), Self.maximumFontSize)
        editorLineHeight = min(max(editorLineHeight, Self.minimumLineHeight), Self.maximumLineHeight)
    }
}

extension AppSettings {
    private enum StorageKey {
        static let editorFontSize = "settings.editorFontSize"
        static let editorFontFamily = "settings.editorFontFamily"
        static let editorLineHeight = "settings.editorLineHeight"
        static let showLineNumbers = "settings.showLineNumbers"
        static let wrapLines = "settings.wrapLines"
        static let hideSyntax = "settings.hideSyntax"
        static let showPreview = "settings.showPreview"
    }

    static func load(from defaults: UserDefaults) -> AppSettings {
        var settings = AppSettings()

        if defaults.object(forKey: StorageKey.editorFontSize) != nil {
            settings.editorFontSize = defaults.double(forKey: StorageKey.editorFontSize)
        }

        if let rawValue = defaults.string(forKey: StorageKey.editorFontFamily),
           let fontFamily = EditorFontFamily(rawValue: rawValue) {
            settings.editorFontFamily = fontFamily
        }

        if defaults.object(forKey: StorageKey.editorLineHeight) != nil {
            settings.editorLineHeight = defaults.double(forKey: StorageKey.editorLineHeight)
        }

        if defaults.object(forKey: StorageKey.showLineNumbers) != nil {
            settings.showLineNumbers = defaults.bool(forKey: StorageKey.showLineNumbers)
        }

        if defaults.object(forKey: StorageKey.wrapLines) != nil {
            settings.wrapLines = defaults.bool(forKey: StorageKey.wrapLines)
        }

        if defaults.object(forKey: StorageKey.hideSyntax) != nil {
            settings.hideSyntax = defaults.bool(forKey: StorageKey.hideSyntax)
        }

        if defaults.object(forKey: StorageKey.showPreview) != nil {
            settings.showPreview = defaults.bool(forKey: StorageKey.showPreview)
        }

        settings.clampValues()
        return settings
    }

    func save(to defaults: UserDefaults) {
        defaults.set(editorFontSize, forKey: StorageKey.editorFontSize)
        defaults.set(editorFontFamily.rawValue, forKey: StorageKey.editorFontFamily)
        defaults.set(editorLineHeight, forKey: StorageKey.editorLineHeight)
        defaults.set(showLineNumbers, forKey: StorageKey.showLineNumbers)
        defaults.set(wrapLines, forKey: StorageKey.wrapLines)
        defaults.set(hideSyntax, forKey: StorageKey.hideSyntax)
        defaults.set(showPreview, forKey: StorageKey.showPreview)
    }
}

enum EditorFontFamily: String, CaseIterable, Equatable, Identifiable {
    case sfMono
    case menlo
    case monaco

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sfMono:
            return "SF Mono"
        case .menlo:
            return "Menlo"
        case .monaco:
            return "Monaco"
        }
    }

    var cssValue: String {
        switch self {
        case .sfMono:
            return "-apple-system, BlinkMacSystemFont, 'SF Mono', Menlo, Monaco, monospace"
        case .menlo:
            return "Menlo, Monaco, monospace"
        case .monaco:
            return "Monaco, Menlo, monospace"
        }
    }
}
