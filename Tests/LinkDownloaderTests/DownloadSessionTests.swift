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
}
