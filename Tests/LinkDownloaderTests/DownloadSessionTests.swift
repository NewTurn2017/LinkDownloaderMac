import Foundation
@testable import LinkDownloader
import XCTest

final class DownloadSessionTests: XCTestCase {
    func testCancelBeforeAttachTerminatesAttachedProcess() throws {
        let session = DownloadSession()
        let process = try DownloadProcess.launch(
            executablePath: "/bin/sleep",
            arguments: ["5"],
            currentDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            environment: ["PATH": "/usr/bin:/bin"]
        )

        session.cancel()
        session.attach(process)
        let terminationStatus = try process.waitUntilExit()
        session.finish()

        XCTAssertTrue(session.isCancelled)
        XCTAssertNotEqual(terminationStatus, 0)
    }

    func testCancelAfterFinishIsNoOp() {
        let session = DownloadSession()

        session.finish()
        session.cancel()

        XCTAssertFalse(session.isCancelled)
    }

    func testCancelTerminatesChildProcess() throws {
        let session = DownloadSession()
        let process = try DownloadProcess.launch(
            executablePath: "/bin/sh",
            arguments: ["-c", "sleep 30 & wait"],
            currentDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            environment: ["PATH": "/usr/bin:/bin"]
        )
        session.attach(process)

        let groupPIDs = try waitForGroupPIDs(groupID: process.processIdentifier)
        XCTAssertGreaterThanOrEqual(groupPIDs.count, 2)

        XCTAssertNil(session.cancel())
        _ = try process.waitUntilExit()
        session.finish()

        for pid in groupPIDs {
            waitUntilNotRunning(pid: pid)
            XCTAssertFalse(isRunning(pid: pid))
        }
        XCTAssertTrue(session.isCancelled)
    }

    private func waitForGroupPIDs(groupID: pid_t) throws -> [pid_t] {
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            let pids = try processGroupPIDs(groupID: groupID)
            if pids.count >= 2 {
                return pids
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        return try processGroupPIDs(groupID: groupID)
    }

    private func processGroupPIDs(groupID: pid_t) throws -> [pid_t] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-g", String(groupID)]
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

    private func waitUntilNotRunning(pid: pid_t) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && isRunning(pid: pid) {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private func isRunning(pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }
}
