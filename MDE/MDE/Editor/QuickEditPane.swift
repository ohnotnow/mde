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
    }
}
