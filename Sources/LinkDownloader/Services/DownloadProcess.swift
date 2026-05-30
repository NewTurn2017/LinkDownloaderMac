import Darwin
import Foundation

enum DownloadCancellationError: Error, Equatable {
    case signalFailed(errnoCode: Int32)
}

final class DownloadProcess: @unchecked Sendable {
    let processIdentifier: pid_t

    private let outputHandle: FileHandle
    private let waitLock = NSLock()
    private var didWait = false
    private var cachedTerminationStatus: Int32?

    private init(processIdentifier: pid_t, outputHandle: FileHandle) {
        self.processIdentifier = processIdentifier
        self.outputHandle = outputHandle
    }

    static func launch(
        executablePath: String,
        arguments: [String],
        currentDirectory: URL,
        environment: [String: String]
    ) throws -> DownloadProcess {
        let pipe = Pipe()
        var fileActions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?

        try check(posix_spawn_file_actions_init(&fileActions))
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        try currentDirectory.path.withCString { path in
            if #available(macOS 26.0, *) {
                try check(posix_spawn_file_actions_addchdir(&fileActions, path))
            } else {
                try check(posix_spawn_file_actions_addchdir_np(&fileActions, path))
            }
        }
        try check(posix_spawn_file_actions_addclose(&fileActions, pipe.fileHandleForReading.fileDescriptor))
        try check(posix_spawn_file_actions_adddup2(&fileActions, pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO))
        try check(posix_spawn_file_actions_adddup2(&fileActions, pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO))
        try check(posix_spawn_file_actions_addclose(&fileActions, pipe.fileHandleForWriting.fileDescriptor))

        try check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }

        try check(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)))
        try check(posix_spawnattr_setpgroup(&attributes, 0))

        let argv = CStringArray([executablePath] + arguments)
        defer { argv.free() }
        let envp = CStringArray(environment.map { "\($0.key)=\($0.value)" }.sorted())
        defer { envp.free() }

        var pid: pid_t = 0
        let spawnResult = executablePath.withCString { executableCString in
            posix_spawn(&pid, executableCString, &fileActions, &attributes, argv.pointer, envp.pointer)
        }
        try check(spawnResult)

        try pipe.fileHandleForWriting.close()
        return DownloadProcess(processIdentifier: pid, outputHandle: pipe.fileHandleForReading)
    }

    func setOutputHandler(_ handler: @escaping (String) -> Void) {
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            handler(text)
        }
    }

    func clearOutputHandler() {
        outputHandle.readabilityHandler = nil
    }

    func waitUntilExit() throws -> Int32 {
        if let cachedTerminationStatus = waitLock.withLock({ cachedTerminationStatus }) {
            return cachedTerminationStatus
        }

        var status: Int32 = 0
        while waitpid(processIdentifier, &status, 0) == -1 {
            if errno != EINTR {
                throw posixError(errno)
            }
        }

        let terminationStatus = Self.normalizedTerminationStatus(from: status)

        waitLock.withLock {
            cachedTerminationStatus = terminationStatus
            didWait = true
        }
        return terminationStatus
    }

    func terminateGroup() -> DownloadCancellationError? {
        if kill(-processIdentifier, SIGTERM) == -1 {
            let code = errno
            if code != ESRCH {
                return .signalFailed(errnoCode: code)
            }
        }
        return nil
    }

    private static func check(_ code: Int32) throws {
        guard code == 0 else {
            throw posixError(code)
        }
    }

    private static func normalizedTerminationStatus(from status: Int32) -> Int32 {
        let maskedStatus = status & 0o177
        if maskedStatus == 0 {
            return (status >> 8) & 0xff
        }
        if maskedStatus != 0o177 {
            return 128 + maskedStatus
        }
        return status
    }
}

private final class CStringArray {
    let pointer: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    private let count: Int

    init(_ strings: [String]) {
        count = strings.count
        pointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count + 1)

        for (index, string) in strings.enumerated() {
            pointer[index] = strdup(string)
        }
        pointer[count] = nil
    }

    func free() {
        for index in 0..<count {
            Darwin.free(pointer[index])
        }
        pointer.deallocate()
    }
}

private func posixError(_ code: Int32) -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code))
}
