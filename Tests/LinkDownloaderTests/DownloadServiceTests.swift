import Foundation
@testable import LinkDownloader
import XCTest

final class DownloadServiceTests: XCTestCase {
    func testVideoArgumentsForceMP4OutputByDefault() {
        let destination = URL(fileURLWithPath: "/tmp/downloads")
        let arguments = DownloadService.videoArguments(
            urlString: "https://www.youtube.com/watch?v=test",
            destination: destination,
            options: .standard
        )

        XCTAssertTrue(arguments.contains("--no-playlist"))
        XCTAssertFalse(arguments.contains("--yes-playlist"))
        XCTAssertContainsSubsequence(arguments, ["--merge-output-format", "mp4"])
        XCTAssertContainsSubsequence(arguments, ["--recode-video", "mp4"])
        XCTAssertContainsSubsequence(arguments, ["-S", "vcodec:h264,lang,quality,res,fps,hdr:12,acodec:aac"])
        XCTAssertTrue(arguments.contains("--write-info-json"))
        XCTAssertTrue(arguments.contains("--write-thumbnail"))
    }

    func testPlaylistOptionUsesPlaylistMode() {
        let arguments = DownloadService.videoArguments(
            urlString: "https://www.youtube.com/playlist?list=test",
            destination: URL(fileURLWithPath: "/tmp/downloads"),
            options: DownloadOptions(extractMP3: false, includePlaylist: true)
        )

        XCTAssertTrue(arguments.contains("--yes-playlist"))
        XCTAssertFalse(arguments.contains("--no-playlist"))
    }

    func testAudioArgumentsExtractMP3WithoutVideoSidecars() {
        let arguments = DownloadService.audioArguments(
            urlString: "https://www.youtube.com/watch?v=test",
            destination: URL(fileURLWithPath: "/tmp/downloads"),
            options: DownloadOptions(extractMP3: true, includePlaylist: false)
        )

        XCTAssertContainsSubsequence(arguments, ["-f", "ba/b"])
        XCTAssertContainsSubsequence(arguments, ["--audio-format", "mp3"])
        XCTAssertContainsSubsequence(arguments, ["--audio-quality", "0"])
        XCTAssertTrue(arguments.contains("--extract-audio"))
        XCTAssertFalse(arguments.contains("--write-info-json"))
        XCTAssertFalse(arguments.contains("--write-thumbnail"))
    }

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

private func XCTAssertContainsSubsequence(
    _ values: [String],
    _ expected: [String],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard !expected.isEmpty, values.count >= expected.count else {
        XCTFail("Expected \(values) to contain \(expected)", file: file, line: line)
        return
    }

    for index in 0...(values.count - expected.count) {
        if Array(values[index..<(index + expected.count)]) == expected {
            return
        }
    }

    XCTFail("Expected \(values) to contain \(expected)", file: file, line: line)
}
