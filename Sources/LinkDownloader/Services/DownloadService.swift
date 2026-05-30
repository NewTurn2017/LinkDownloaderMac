import Foundation

final class DownloadService {
    func download(
        urlString: String,
        destination: URL,
        options: DownloadOptions = .standard,
        session: DownloadSession,
        onOutput: @escaping (String) -> Void
    ) async throws -> DownloadResult {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let parsedURL = URL(string: trimmedURL),
            let scheme = parsedURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            throw DownloadServiceError.invalidURL
        }

        guard let ytDLPPath = ShellLocator.findExecutable(named: "yt-dlp") else {
            throw DownloadServiceError.missingYTDLP
        }
        guard ShellLocator.findExecutable(named: "ffmpeg") != nil else {
            throw DownloadServiceError.missingFFmpeg
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let beforeFiles = try Self.snapshotFiles(in: destination)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.runYTDLP(
                        executablePath: ytDLPPath,
                        arguments: Self.videoArguments(
                            urlString: trimmedURL,
                            destination: destination,
                            options: options
                        ),
                        currentDirectory: destination,
                        session: session,
                        onOutput: onOutput
                    )

                    if options.extractMP3, !session.isCancelled {
                        onOutput("\nMP3 추출을 시작합니다.\n")
                        try Self.runYTDLP(
                            executablePath: ytDLPPath,
                            arguments: Self.audioArguments(
                                urlString: trimmedURL,
                                destination: destination,
                                options: options
                            ),
                            currentDirectory: destination,
                            session: session,
                            onOutput: onOutput
                        )
                    }

                    session.finish()
                    let afterFiles = try Self.snapshotFiles(in: destination)
                    let createdFiles = afterFiles.subtracting(beforeFiles).sorted { $0.lastPathComponent < $1.lastPathComponent }
                    continuation.resume(returning: DownloadResult(createdFiles: createdFiles))
                } catch {
                    session.finish()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runYTDLP(
        executablePath: String,
        arguments: [String],
        currentDirectory: URL,
        session: DownloadSession,
        onOutput: @escaping (String) -> Void
    ) throws {
        let process = try DownloadProcess.launch(
            executablePath: executablePath,
            arguments: arguments,
            currentDirectory: currentDirectory,
            environment: ShellLocator.environmentWithDefaultPath()
        )
        process.setOutputHandler(onOutput)
        session.attach(process)
        defer { process.clearOutputHandler() }

        let terminationStatus = try process.waitUntilExit()
        guard terminationStatus == 0 else {
            throw DownloadServiceError.processFailed(status: terminationStatus)
        }
    }

    static func videoArguments(
        urlString: String,
        destination: URL,
        options: DownloadOptions
    ) -> [String] {
        baseArguments(destination: destination, options: options) + [
            "-o", "%(title).200B_%(id)s.%(ext)s",
            "--windows-filenames",
            "--write-info-json",
            "--write-thumbnail",
            "--merge-output-format", "mp4",
            "--recode-video", "mp4",
            "-S", "vcodec:h264,lang,quality,res,fps,hdr:12,acodec:aac",
            urlString
        ]
    }

    static func audioArguments(
        urlString: String,
        destination: URL,
        options: DownloadOptions
    ) -> [String] {
        baseArguments(destination: destination, options: options) + [
            "-f", "ba/b",
            "-o", "%(title).200B_%(id)s.%(ext)s",
            "--windows-filenames",
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            urlString
        ]
    }

    private static func baseArguments(destination: URL, options: DownloadOptions) -> [String] {
        [
            "--newline",
            options.includePlaylist ? "--yes-playlist" : "--no-playlist",
            "-P", destination.path
        ]
    }

    static func snapshotFiles(in directory: URL) throws -> Set<URL> {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return Set(try contents.filter { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true
        })
    }
}
