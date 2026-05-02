import Foundation

struct DetectedInternalEditor: Identifiable, Hashable {
    let displayName: String
    let command: String

    var id: String { command }
}

struct InternalEditorService {
    private struct Candidate {
        let binary: String
        let displayName: String
        let command: String
    }

    private static let candidates: [Candidate] = [
        Candidate(binary: "nvim", displayName: "Neovim", command: "nvim"),
        Candidate(binary: "vim", displayName: "Vim", command: "vim"),
        Candidate(binary: "hx", displayName: "Helix", command: "hx"),
        Candidate(binary: "micro", displayName: "Micro", command: "micro"),
        Candidate(binary: "nano", displayName: "Nano", command: "nano"),
        Candidate(binary: "emacs", displayName: "Emacs (TUI)", command: "emacs -nw"),
    ]

    func installedEditors() -> [DetectedInternalEditor] {
        let directories = LoginShellEnvironment.shared.path
            .split(separator: ":")
            .map(String.init)

        let fileManager = FileManager.default

        return InternalEditorService.candidates.compactMap { candidate in
            for directory in directories {
                let fullPath = (directory as NSString).appendingPathComponent(candidate.binary)
                if fileManager.isExecutableFile(atPath: fullPath) {
                    return DetectedInternalEditor(
                        displayName: candidate.displayName,
                        command: candidate.command
                    )
                }
            }
            return nil
        }
    }

    func resolveExecutable(forCommand command: String) -> (executable: URL, arguments: [String])? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let head = parts.first else { return nil }
        let arguments = Array(parts.dropFirst())

        let directories = LoginShellEnvironment.shared.path
            .split(separator: ":")
            .map(String.init)

        let fileManager = FileManager.default

        if head.hasPrefix("/") {
            return fileManager.isExecutableFile(atPath: head)
                ? (URL(fileURLWithPath: head), arguments)
                : nil
        }

        for directory in directories {
            let fullPath = (directory as NSString).appendingPathComponent(head)
            if fileManager.isExecutableFile(atPath: fullPath) {
                return (URL(fileURLWithPath: fullPath), arguments)
            }
        }

        return nil
    }
}
