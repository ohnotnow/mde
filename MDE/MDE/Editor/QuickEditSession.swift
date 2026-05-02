import Foundation

struct QuickEditSession: Identifiable, Equatable {
    let id = UUID()
    let executable: URL
    let arguments: [String]
    let environment: [String]
    let fileURL: URL
    let editorCommand: String
    let fontSize: Double

    static func == (lhs: QuickEditSession, rhs: QuickEditSession) -> Bool {
        lhs.id == rhs.id
    }
}
