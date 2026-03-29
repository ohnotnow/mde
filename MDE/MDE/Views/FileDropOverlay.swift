import AppKit
import SwiftUI

struct FileDropOverlay: NSViewRepresentable {
    let onDrop: (URL) -> Void
    let onTargetChange: (Bool) -> Void

    func makeNSView(context: Context) -> FileDropTargetView {
        let view = FileDropTargetView()
        view.onDrop = onDrop
        view.onTargetChange = onTargetChange
        return view
    }

    func updateNSView(_ nsView: FileDropTargetView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onTargetChange = onTargetChange
    }
}

final class FileDropTargetView: NSView {
    var onDrop: ((URL) -> Void)?
    var onTargetChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrop(from: sender) else {
            onTargetChange?(false)
            return []
        }

        onTargetChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canAcceptDrop(from: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { onTargetChange?(false) }

        guard let url = droppedFileURL(from: sender) else {
            return false
        }

        onDrop?(url)
        return true
    }

    private func canAcceptDrop(from sender: NSDraggingInfo) -> Bool {
        droppedFileURL(from: sender) != nil
    }

    private func droppedFileURL(from sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        return sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: options)?
            .compactMap { $0 as? URL }
            .first
    }
}
