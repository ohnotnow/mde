import Foundation

final class FileWatchService {
    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "ohffs.MDE.FileWatchService", qos: .utility)
    private let debounceInterval: TimeInterval = 0.15

    var onChange: (() -> Void)?

    func watch(_ url: URL) {
        stop()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedNotify()
        }

        source.setCancelHandler {
            close(fd)
        }

        self.source = source
        watchedURL = url
        source.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        watchedURL = nil
    }

    private func scheduleDebouncedNotify() {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let url = self.watchedURL
            DispatchQueue.main.async {
                self.onChange?()
                if let url {
                    self.watch(url)
                }
            }
        }

        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    deinit {
        stop()
    }
}
