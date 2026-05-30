import Foundation

final class DownloadSession: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }

    func attach(_ process: Process) {
        var shouldTerminate = false

        lock.withLock {
            if cancelled {
                shouldTerminate = true
            } else {
                self.process = process
            }
        }

        if shouldTerminate {
            process.terminate()
        }
    }

    func cancel() {
        let processToTerminate = lock.withLock {
            cancelled = true
            return process
        }

        processToTerminate?.terminate()
    }

    func finish() {
        lock.withLock {
            process = nil
        }
    }
}
