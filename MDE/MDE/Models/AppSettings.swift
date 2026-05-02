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
    var externalEditor: ExternalEditorPreference = .systemDefault

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
        static let externalEditor = "settings.externalEditor"
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
           let fontFamily = ReaderFontFamily(storageValue: rawValue) {
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

        if let rawValue = defaults.string(forKey: StorageKey.externalEditor),
           let preference = ExternalEditorPreference(storageValue: rawValue) {
            settings.externalEditor = preference
        }

        settings.clampValues()
        return settings
    }

    func save(to defaults: UserDefaults) {
        defaults.set(readerFontSize, forKey: StorageKey.readerFontSize)
        defaults.set(readerFontFamily.storageValue, forKey: StorageKey.readerFontFamily)
        defaults.set(readerLineHeight, forKey: StorageKey.readerLineHeight)

        switch externalEditor.storageValue {
        case .some(let value):
            defaults.set(value, forKey: StorageKey.externalEditor)
        case .none:
            defaults.removeObject(forKey: StorageKey.externalEditor)
        }
    }
}

enum ExternalEditorPreference: Equatable, Hashable {
    case systemDefault
    case bundleID(String)
    case customApp(URL)

    var storageValue: String? {
        switch self {
        case .systemDefault:
            return nil
        case .bundleID(let id):
            return "bundle:\(id)"
        case .customApp(let url):
            return "path:\(url.path)"
        }
    }

    init?(storageValue: String) {
        if storageValue.hasPrefix("bundle:") {
            let id = String(storageValue.dropFirst("bundle:".count))
            guard !id.isEmpty else { return nil }
            self = .bundleID(id)
        } else if storageValue.hasPrefix("path:") {
            let path = String(storageValue.dropFirst("path:".count))
            guard !path.isEmpty else { return nil }
            self = .customApp(URL(fileURLWithPath: path))
        } else {
            return nil
        }
    }
}

enum ReaderFontFamily: Hashable, Identifiable {
    case system
    case serif
    case mono
    case custom(String)

    static let presets: [ReaderFontFamily] = [.system, .serif, .mono]

    var id: String { storageValue }

    var label: String {
        switch self {
        case .system:
            return "System Sans"
        case .serif:
            return "System Serif"
        case .mono:
            return "Monospaced"
        case .custom(let name):
            return name
        }
    }

    var storageValue: String {
        switch self {
        case .system:
            return "system"
        case .serif:
            return "serif"
        case .mono:
            return "mono"
        case .custom(let name):
            return "custom:\(name)"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "system":
            self = .system
        case "serif":
            self = .serif
        case "mono":
            self = .mono
        default:
            guard storageValue.hasPrefix("custom:") else {
                return nil
            }
            let name = String(storageValue.dropFirst("custom:".count))
            guard !name.isEmpty else {
                return nil
            }
            self = .custom(name)
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
