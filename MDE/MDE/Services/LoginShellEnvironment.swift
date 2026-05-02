import Foundation

enum LoginShellEnvironment {
    static let fallbackPath = "/usr/bin:/bin:/usr/sbin:/sbin"

    struct Snapshot {
        let shell: String
        let path: String
    }

    static let shared: Snapshot = capture()

    static var loginShell: String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell {
            return String(cString: shell)
        }
        return "/bin/zsh"
    }

    static func capture(timeout: TimeInterval = 1.0) -> Snapshot {
        let shell = loginShell
        return Snapshot(shell: shell, path: probePath(for: shell, timeout: timeout))
    }

    private static func probePath(for shell: String, timeout: TimeInterval) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", "env"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return fallbackPath
        }

        let exited = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            exited.signal()
        }

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return fallbackPath
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return fallbackPath
        }

        for line in text.split(separator: "\n") where line.hasPrefix("PATH=") {
            let value = String(line.dropFirst("PATH=".count))
            return value.isEmpty ? fallbackPath : value
        }

        return fallbackPath
    }
}
