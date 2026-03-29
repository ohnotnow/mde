import Combine
import UniformTypeIdentifiers
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var document = MarkdownDocument.sample
    @Published var settings = AppSettings()
    @Published var alertMessage: String?
    @Published var pendingConfirmation: PendingConfirmation?

    let editorEngine: any EditorEngine
    let previewEngine: any PreviewEngine
    private let fileService: FileDocumentService

    init() {
        self.editorEngine = PlainTextEditorEngine()
        self.previewEngine = NativeMarkdownPreviewEngine()
        self.fileService = FileDocumentService()
    }

    var canSave: Bool {
        document.isDirty || document.fileURL != nil
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
