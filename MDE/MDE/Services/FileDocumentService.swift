import AppKit
import Foundation
import UniformTypeIdentifiers

enum FileDialogCancellation: Error {
    case cancelled
}

struct FileDocumentService {
    func openMarkdownDocument() throws -> MarkdownDocument {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = supportedTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            throw FileDialogCancellation.cancelled
        }

        return try loadDocument(from: url)
    }

    func save(document: MarkdownDocument) throws -> MarkdownDocument {
        if let url = document.fileURL {
            return try write(document: document, to: url)
        }

        return try saveAs(document: document)
    }

    func saveAs(document: MarkdownDocument) throws -> MarkdownDocument {
        let panel = NSSavePanel()
        panel.allowedContentTypes = supportedTypes
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = document.fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            throw FileDialogCancellation.cancelled
        }

        return try write(document: document, to: url)
    }

    private func loadDocument(from url: URL) throws -> MarkdownDocument {
        let text = try String(contentsOf: url, encoding: .utf8)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        return MarkdownDocument(
            text: text,
            fileURL: url,
            isDirty: false
        )
    }

    private func write(document: MarkdownDocument, to url: URL) throws -> MarkdownDocument {
        try document.text.write(to: url, atomically: true, encoding: .utf8)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        var saved = document
        saved.fileURL = url
        saved.isDirty = false
        return saved
    }

    private var supportedTypes: [UTType] {
        if let markdown = UTType(filenameExtension: "md") {
            return [markdown, .plainText]
        }

        return [.plainText]
    }
}
