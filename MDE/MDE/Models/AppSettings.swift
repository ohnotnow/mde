import Foundation
import SwiftUI

struct AppSettings: Equatable {
    static let minimumFontSize = 10.0
    static let maximumFontSize = 72.0
    static let defaultFontSize = 18.0
    static let minimumLineHeight = 1.1
    static let maximumLineHeight = 2.2

    var readerFontSize: Double = AppSettings.defaultFontSize
    var readerFontFamily: ReaderFontFamily = .serif
    var readerLineHeight: Double = 1.5
    var rendererChoice: RendererChoice = .markdownUI

    mutating func increaseFontSize() {
        readerFontSize = min(readerFontSize + 1, Self.maximumFontSize)
    }

    mutating func decreaseFontSize() {
        readerFontSize = max(readerFontSize - 1, Self.minimumFontSize)
    }

    mutating func resetFontSize() {
        readerFontSize = Self.defaultFontSize
    }

    mutating func clampValues() {
        readerFontSize = min(max(readerFontSize, Self.minimumFontSize), Self.maximumFontSize)
        readerLineHeight = min(max(readerLineHeight, Self.minimumLineHeight), Self.maximumLineHeight)
    }
}

extension AppSettings {
    private enum StorageKey {
        static let readerFontSize = "settings.readerFontSize"
        static let readerFontFamily = "settings.readerFontFamily"
        static let readerLineHeight = "settings.readerLineHeight"
        static let rendererChoice = "settings.rendererChoice"
        static let legacyEditorFontSize = "settings.editorFontSize"
        static let legacyEditorFontFamily = "settings.editorFontFamily"
        static let legacyEditorLineHeight = "settings.editorLineHeight"
    }

    static func load(from defaults: UserDefaults) -> AppSettings {
        var settings = AppSettings()

        if defaults.object(forKey: StorageKey.readerFontSize) != nil {
            settings.readerFontSize = defaults.double(forKey: StorageKey.readerFontSize)
        } else if defaults.object(forKey: StorageKey.legacyEditorFontSize) != nil {
            settings.readerFontSize = defaults.double(forKey: StorageKey.legacyEditorFontSize)
        }

        if let rawValue = defaults.string(forKey: StorageKey.readerFontFamily),
           let fontFamily = ReaderFontFamily(rawValue: rawValue) {
            settings.readerFontFamily = fontFamily
        } else if let rawValue = defaults.string(forKey: StorageKey.legacyEditorFontFamily),
                  let fontFamily = ReaderFontFamily.legacy(rawValue: rawValue) {
            settings.readerFontFamily = fontFamily
        }

        if defaults.object(forKey: StorageKey.readerLineHeight) != nil {
            settings.readerLineHeight = defaults.double(forKey: StorageKey.readerLineHeight)
        } else if defaults.object(forKey: StorageKey.legacyEditorLineHeight) != nil {
            settings.readerLineHeight = defaults.double(forKey: StorageKey.legacyEditorLineHeight)
        }

        if let rawValue = defaults.string(forKey: StorageKey.rendererChoice),
           let choice = RendererChoice(rawValue: rawValue) {
            settings.rendererChoice = choice
        }

        settings.clampValues()
        return settings
    }

    func save(to defaults: UserDefaults) {
        defaults.set(readerFontSize, forKey: StorageKey.readerFontSize)
        defaults.set(readerFontFamily.rawValue, forKey: StorageKey.readerFontFamily)
        defaults.set(readerLineHeight, forKey: StorageKey.readerLineHeight)
        defaults.set(rendererChoice.rawValue, forKey: StorageKey.rendererChoice)
    }
}

enum RendererChoice: String, CaseIterable, Equatable, Identifiable {
    case markdownUI
    case native

    var id: String { rawValue }

    var label: String {
        switch self {
        case .markdownUI:
            return "MarkdownUI (spike)"
        case .native:
            return "Native (AttributedString)"
        }
    }
}

enum ReaderFontFamily: String, CaseIterable, Equatable, Identifiable {
    case system
    case serif
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "System Sans"
        case .serif:
            return "System Serif"
        case .mono:
            return "Monospaced"
        }
    }

    var cssValue: String {
        switch self {
        case .system:
            return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif"
        case .serif:
            return "'New York', Georgia, serif"
        case .mono:
            return "'SF Mono', Menlo, Monaco, monospace"
        }
    }

    func swiftUIFont(size: Double) -> Font {
        switch self {
        case .system:
            return .system(size: size, design: .default)
        case .serif:
            return .system(size: size, design: .serif)
        case .mono:
            return .system(size: size, design: .monospaced)
        }
    }

    static func legacy(rawValue: String) -> ReaderFontFamily? {
        switch rawValue {
        case "system", "sfMono":
            return .system
        case "serif":
            return .serif
        case "mono", "menlo", "monaco":
            return .mono
        default:
            return nil
        }
    }
}
