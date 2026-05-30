import Darwin
import Foundation

final class DownloadSession: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var finished = false

    var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }

    func attach(_ process: Process) {
        var shouldTerminate = false

        lock.withLock {
            if cancelled || finished {
                shouldTerminate = true
            } else {
                self.process = process
            }
        }

        if shouldTerminate {
            terminateProcessTree(root: process)
        }
    }

    func cancel() {
        let processToTerminate = lock.withLock {
            guard !finished else {
                return nil as Process?
            }

            cancelled = true
            return process
        }

        if let processToTerminate {
            terminateProcessTree(root: processToTerminate)
        }
    }

    func finish() {
        lock.withLock {
            finished = true
            process = nil
        }
    }

    private func terminateProcessTree(root: Process) {
        for childPID in Self.descendantPIDs(of: root.processIdentifier) {
            kill(childPID, SIGTERM)
        }
        root.terminate()
    }

    private static func descendantPIDs(of pid: pid_t) -> [pid_t] {
        childPIDs(of: pid).flatMap { childPID in
            descendantPIDs(of: childPID) + [childPID]
        }
    }

    private static func childPIDs(of pid: pid_t) -> [pid_t] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(pid)]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}
