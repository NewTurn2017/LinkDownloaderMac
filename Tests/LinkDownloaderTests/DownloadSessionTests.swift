import Foundation
@testable import LinkDownloader
import XCTest

final class DownloadSessionTests: XCTestCase {
    func testCancelBeforeAttachTerminatesAttachedProcess() throws {
        let session = DownloadSession()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["5"]

        session.cancel()
        try process.run()
        session.attach(process)
        process.waitUntilExit()
        session.finish()

        XCTAssertTrue(session.isCancelled)
        XCTAssertNotEqual(process.terminationStatus, 0)
    }

    func testCancelAfterFinishIsNoOp() {
        let session = DownloadSession()

        session.finish()
        session.cancel()

        XCTAssertFalse(session.isCancelled)
    }

    func testCancelTerminatesChildProcess() throws {
        let session = DownloadSession()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 30 & wait"]

        try process.run()
        session.attach(process)

        let childPIDs = try waitForChildPIDs(parentPID: process.processIdentifier)
        XCTAssertFalse(childPIDs.isEmpty)

        session.cancel()
        process.waitUntilExit()
        session.finish()

        for childPID in childPIDs {
            XCTAssertFalse(isRunning(pid: childPID))
        }
        XCTAssertTrue(session.isCancelled)
    }

    private func waitForChildPIDs(parentPID: pid_t) throws -> [pid_t] {
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            let pids = try childPIDs(parentPID: parentPID)
            if !pids.isEmpty {
                return pids
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        return try childPIDs(parentPID: parentPID)
    }

    private func childPIDs(parentPID: pid_t) throws -> [pid_t] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(parentPID)]
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func isRunning(pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }
}
