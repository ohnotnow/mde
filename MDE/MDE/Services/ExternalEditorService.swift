import AppKit
import Foundation

struct ExternalEditor: Identifiable, Hashable {
    let bundleID: String
    let appURL: URL
    let displayName: String

    var id: String { bundleID }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

struct ExternalEditorService {
    func installedEditors() -> [ExternalEditor] {
        ExternalEditorService.knownEditors.compactMap { candidate in
            guard let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: candidate.bundleID
            ) else {
                return nil
            }

            let displayName = bundleDisplayName(at: appURL) ?? candidate.fallbackName

            return ExternalEditor(
                bundleID: candidate.bundleID,
                appURL: appURL,
                displayName: displayName
            )
        }
    }

    private func bundleDisplayName(at appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else {
            return nil
        }

        let candidateKeys = ["CFBundleDisplayName", "CFBundleName"]

        for key in candidateKeys {
            if let value = bundle.localizedInfoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
            if let value = bundle.infoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private struct KnownEditor {
        let bundleID: String
        let fallbackName: String
    }

    private static let knownEditors: [KnownEditor] = [
        KnownEditor(bundleID: "com.microsoft.VSCode", fallbackName: "Visual Studio Code"),
        KnownEditor(bundleID: "com.todesktop.230313mzl4w4u92", fallbackName: "Cursor"),
        KnownEditor(bundleID: "dev.zed.Zed", fallbackName: "Zed"),
        KnownEditor(bundleID: "com.sublimetext.4", fallbackName: "Sublime Text"),
        KnownEditor(bundleID: "com.barebones.bbedit", fallbackName: "BBEdit"),
        KnownEditor(bundleID: "com.panic.Nova", fallbackName: "Nova"),
        KnownEditor(bundleID: "org.vim.MacVim", fallbackName: "MacVim"),
        KnownEditor(bundleID: "com.macromates.TextMate", fallbackName: "TextMate"),
    ]
}
