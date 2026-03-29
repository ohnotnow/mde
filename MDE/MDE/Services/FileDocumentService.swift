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

    func loadDocument(from url: URL) throws -> MarkdownDocument {
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

    func canOpen(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return supportedTypes.contains(where: { type.conforms(to: $0) })
        }

        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.plainText]

        if let markdown = UTType(filenameExtension: "md") {
            types.insert(markdown, at: 0)
        }

        if let markdown = UTType(filenameExtension: "markdown"), !types.contains(markdown) {
            types.insert(markdown, at: 0)
        }

        return types
    }

    private var supportedExtensions: Set<String> {
        ["md", "markdown", "mdown", "mkd", "txt"]
    }
}
