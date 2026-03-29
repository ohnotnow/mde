import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appModel: AppModel?

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let appModel, let path = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        appModel.openDocument(at: URL(fileURLWithPath: path))
        sender.reply(toOpenOrPrint: .success)
    }
}
