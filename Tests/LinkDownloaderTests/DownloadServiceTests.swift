import Foundation
@testable import LinkDownloader
import XCTest

final class DownloadServiceTests: XCTestCase {
    func testSnapshotFilesThrowsForMissingDirectory() {
        let missingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try DownloadService.snapshotFiles(in: missingDirectory))
    }

    func testSnapshotFilesIncludesOnlyRegularFiles() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("video.mp4")
        let nestedDirectory = directory.appendingPathComponent("nested")
        try Data("ok".utf8).write(to: file)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        let files = try DownloadService.snapshotFiles(in: directory)

        XCTAssertEqual(
            Set(files.map(\.standardizedFileURL)),
            [file.standardizedFileURL]
        )
    }
}
