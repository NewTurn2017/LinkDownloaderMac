import Foundation

final class DownloadService {
    func download(
        urlString: String,
        destination: URL,
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

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let beforeFiles = try Self.snapshotFiles(in: destination)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let arguments = [
                    "--newline",
                    "--no-playlist",
                    "-P", destination.path,
                    "-o", "%(uploader)s_%(id)s.%(ext)s",
                    "--write-info-json",
                    "--write-thumbnail",
                    trimmedURL
                ]

                do {
                    let process = try DownloadProcess.launch(
                        executablePath: ytDLPPath,
                        arguments: arguments,
                        currentDirectory: destination,
                        environment: ShellLocator.environmentWithDefaultPath()
                    )
                    process.setOutputHandler(onOutput)
                    session.attach(process)
                    let terminationStatus = try process.waitUntilExit()
                    session.finish()
                    process.clearOutputHandler()

                    guard terminationStatus == 0 else {
                        continuation.resume(throwing: DownloadServiceError.processFailed(status: terminationStatus))
                        return
                    }

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
