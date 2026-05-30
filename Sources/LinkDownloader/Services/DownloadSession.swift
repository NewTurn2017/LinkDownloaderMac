import Foundation

final class DownloadSession: @unchecked Sendable {
    private let lock = NSLock()
    private var process: DownloadProcess?
    private var cancelled = false
    private var finished = false
    private var cancellationError: DownloadCancellationError?

    var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }

    var lastCancellationError: DownloadCancellationError? {
        lock.withLock {
            cancellationError
        }
    }

    func attach(_ process: DownloadProcess) {
        var shouldTerminate = false
        lock.withLock {
            if cancelled || finished {
                shouldTerminate = true
            } else {
                self.process = process
            }
        }

        if shouldTerminate {
            recordCancellationError(process.terminateGroup())
        }
    }

    @discardableResult
    func cancel() -> DownloadCancellationError? {
        let processToTerminate = lock.withLock {
            guard !finished else {
                return nil as DownloadProcess?
            }

            cancelled = true
            return process
        }

        if let processToTerminate {
            let error = processToTerminate.terminateGroup()
            recordCancellationError(error)
            return error
        }
        return nil
    }

    func finish() {
        lock.withLock {
            finished = true
            process = nil
        }
    }

    private func recordCancellationError(_ error: DownloadCancellationError?) {
        guard let error else { return }
        lock.withLock {
            cancellationError = error
        }
    }
}
