import Combine
import AppKit
import UniformTypeIdentifiers
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var document = MarkdownDocument.sample
    @Published var settings: AppSettings
    @Published var alertMessage: String?
    @Published var pendingConfirmation: PendingConfirmation?

    let editorEngine: any EditorEngine
    let previewEngine: any PreviewEngine
    private let fileService: FileDocumentService
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.defaults = .standard
        self.editorEngine = CodeMirrorEditorEngine()
        self.previewEngine = NativeMarkdownPreviewEngine()
        self.fileService = FileDocumentService()
        self.settings = AppSettings.load(from: defaults)

        $settings
            .dropFirst()
            .sink { [defaults] settings in
                settings.save(to: defaults)
            }
            .store(in: &cancellables)
    }

    var canSave: Bool {
        document.isDirty || document.fileURL != nil
    }

    var recentDocuments: [URL] {
        NSDocumentController.shared.recentDocumentURLs.filter(fileService.canOpen)
    }

    func newDocument() {
        guardIfNeeded(for: .newDocument) {
            self.document = MarkdownDocument.empty
        }
    }

    func openDocument() {
        guardIfNeeded(for: .openDocument) {
            do {
                let opened = try self.fileService.openMarkdownDocument()
                self.document = opened
            } catch FileDialogCancellation.cancelled {
                return
            } catch {
                self.presentError(error)
            }
        }
    }

    func openDocument(at url: URL) {
        guard fileService.canOpen(url) else {
            alertMessage = "The selected file type is not supported."
            return
        }

        guardIfNeeded(for: .openDocument) {
            do {
                self.document = try self.fileService.loadDocument(from: url)
            } catch {
                self.presentError(error)
            }
        }
    }

    func openRecentDocument(_ url: URL) {
        openDocument(at: url)
    }

    func clearRecentDocuments() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        objectWillChange.send()
    }

    func saveDocument() {
        do {
            let saved = try fileService.save(document: document)
            document = saved
        } catch FileDialogCancellation.cancelled {
            return
        } catch {
            presentError(error)
        }
    }

    func saveDocumentAs() {
        do {
            let saved = try fileService.saveAs(document: document)
            document = saved
        } catch FileDialogCancellation.cancelled {
            return
        } catch {
            presentError(error)
        }
    }

    func togglePreview() {
        settings.showPreview.toggle()
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
        settings.editorFontSize = value
        settings.clampValues()
    }

    func updateLineHeight(to value: Double) {
        settings.editorLineHeight = value
        settings.clampValues()
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func confirmPendingAction() {
        guard let pendingConfirmation else {
            return
        }

        self.pendingConfirmation = nil
        pendingConfirmation.action()
    }

    func cancelPendingAction() {
        pendingConfirmation = nil
    }

    private func guardIfNeeded(
        for action: ConfirmedAction,
        perform work: @escaping @MainActor () -> Void
    ) {
        guard document.isDirty else {
            work()
            return
        }

        pendingConfirmation = PendingConfirmation(
            title: action.confirmationTitle,
            message: action.confirmationMessage
        ) {
            work()
        }
    }

    private func presentError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

extension AppModel {
    struct PendingConfirmation: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let action: @MainActor () -> Void
    }

    enum ConfirmedAction {
        case newDocument
        case openDocument

        var confirmationTitle: String {
            switch self {
            case .newDocument:
                return "Discard unsaved changes?"
            case .openDocument:
                return "Open another file and discard changes?"
            }
        }

        var confirmationMessage: String {
            "Your current document has unsaved changes."
        }
    }
}
