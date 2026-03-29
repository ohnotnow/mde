import Foundation

struct AppSettings: Equatable {
    static let minimumFontSize = 10.0
    static let maximumFontSize = 72.0
    static let defaultFontSize = 18.0

    var editorFontSize: Double = AppSettings.defaultFontSize
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
    }
}

extension AppSettings {
    private enum StorageKey {
        static let editorFontSize = "settings.editorFontSize"
        static let showPreview = "settings.showPreview"
    }

    static func load(from defaults: UserDefaults) -> AppSettings {
        var settings = AppSettings()

        if defaults.object(forKey: StorageKey.editorFontSize) != nil {
            settings.editorFontSize = defaults.double(forKey: StorageKey.editorFontSize)
        }

        if defaults.object(forKey: StorageKey.showPreview) != nil {
            settings.showPreview = defaults.bool(forKey: StorageKey.showPreview)
        }

        settings.clampValues()
        return settings
    }

    func save(to defaults: UserDefaults) {
        defaults.set(editorFontSize, forKey: StorageKey.editorFontSize)
        defaults.set(showPreview, forKey: StorageKey.showPreview)
    }
}
