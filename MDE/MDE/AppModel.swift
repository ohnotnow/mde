import Combine
import AppKit
import UniformTypeIdentifiers
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var document = MarkdownDocument.sample
    @Published var settings: AppSettings
    @Published var alertMessage: String?

    private let fileService: FileDocumentService
    private let externalEditorService: ExternalEditorService
    private let fileWatcher: FileWatchService
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.defaults = .standard
        self.fileService = FileDocumentService()
        self.externalEditorService = ExternalEditorService()
        self.fileWatcher = FileWatchService()
        self.settings = AppSettings.load(from: defaults)

        fileWatcher.onChange = { [weak self] in
            self?.reloadCurrentDocument()
        }

        $settings
            .dropFirst()
            .sink { [defaults] settings in
                settings.save(to: defaults)
            }
            .store(in: &cancellables)

        $document
            .map(\.fileURL)
            .removeDuplicates()
            .sink { [weak self] url in
                guard let self else { return }
                if let url {
                    self.fileWatcher.watch(url)
                } else {
                    self.fileWatcher.stop()
                }
            }
            .store(in: &cancellables)
    }

    var recentDocuments: [URL] {
        NSDocumentController.shared.recentDocumentURLs.filter(fileService.canOpen)
    }

    var canOpenInExternalEditor: Bool {
        document.fileURL != nil
    }

    func openDocument() {
        do {
            let opened = try self.fileService.openMarkdownDocument()
            self.document = opened
        } catch FileDialogCancellation.cancelled {
            return
        } catch {
            self.presentError(error)
        }
    }

    func openDocument(at url: URL) {
        guard fileService.canOpen(url) else {
            alertMessage = "The selected file type is not supported."
            return
        }

        do {
            document = try fileService.loadDocument(from: url)
        } catch {
            presentError(error)
        }
    }

    func openDroppedDocument(at url: URL) {
        openDocument(at: url)
    }

    func openRecentDocument(_ url: URL) {
        openDocument(at: url)
    }

    func clearRecentDocuments() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        objectWillChange.send()
    }

    func openInExternalEditor() {
        guard let fileURL = document.fileURL else {
            alertMessage = "Save the document before opening it in an external editor."
            return
        }

        guard let appURL = resolveExternalEditorURL() else {
            alertMessage = "Couldn't find an external editor. Choose one in Settings."
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: appURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.presentError(error)
            }
        }
    }

    func increaseFontSize() {
        settings.increaseFontSize()
    }

    func decreaseFontSize() {
        settings.decreaseFontSize()
    }

    func resetFontSize() {
        settings.resetFontSize()
    }

    func updateFontSize(to value: Double) {
        settings.readerFontSize = value
        settings.clampValues()
    }

    func dismissAlert() {
        alertMessage = nil
    }

    private func reloadCurrentDocument() {
        guard let url = document.fileURL else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        document.text = text
    }

    private func resolveExternalEditorURL() -> URL? {
        switch settings.externalEditor {
        case .customApp(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return url
        case .bundleID(let id):
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        case .systemDefault:
            if let detected = externalEditorService.installedEditors().first {
                return detected.appURL
            }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit")
        }
    }

    private func presentError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
