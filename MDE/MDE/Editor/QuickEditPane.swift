import SwiftUI

struct QuickEditPane: View {
    let session: QuickEditSession
    let onExit: (Int32?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text("Editing \(session.fileURL.lastPathComponent) — \(session.editorCommand)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Save and quit your editor to dismiss")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)

            Divider()

            QuickEditTerminalView(session: session, onExit: onExit)
        }
        .frame(minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight)
    }

    private var minHeight: CGFloat {
        max(180, CGFloat(session.fontSize) * 12)
    }

    private var idealHeight: CGFloat {
        max(280, CGFloat(session.fontSize) * 22)
    }

    private var maxHeight: CGFloat {
        min(720, max(420, CGFloat(session.fontSize) * 32))
    }
}
