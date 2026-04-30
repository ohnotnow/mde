import Combine
import AppKit
import UniformTypeIdentifiers
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var document = MarkdownDocument.sample
    @Published var settings: AppSettings
    @Published var alertMessage: String?

    private let nativeRenderer = NativeMarkdownRenderer()
    private let markdownUIRenderer = MarkdownUIRenderer()
    private let fileService: FileDocumentService
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    var renderer: any MarkdownRenderer {
        switch settings.rendererChoice {
        case .markdownUI:
            return markdownUIRenderer
        case .native:
            return nativeRenderer
        }
    }

    init() {
        self.defaults = .standard
        self.fileService = FileDocumentService()
        self.settings = AppSettings.load(from: defaults)

        $settings
            .dropFirst()
            .sink { [defaults] settings in
                settings.save(to: defaults)
            }
            .store(in: &cancellables)
    }

    var recentDocuments: [URL] {
        NSDocumentController.shared.recentDocumentURLs.filter(fileService.canOpen)
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

    private func presentError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
