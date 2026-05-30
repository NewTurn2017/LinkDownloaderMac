import Foundation

final class DownloadService {
    func download(
        urlString: String,
        destination: URL,
        onProcess: @escaping (Process) -> Void,
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
        let beforeFiles = Self.snapshotFiles(in: destination)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: ytDLPPath)
                process.currentDirectoryURL = destination
                process.arguments = [
                    "--newline",
                    "--no-playlist",
                    "-P", destination.path,
                    "-o", "%(uploader)s_%(id)s.%(ext)s",
                    "--write-info-json",
                    "--write-thumbnail",
                    trimmedURL
                ]
                process.environment = ShellLocator.environmentWithDefaultPath()
                process.standardOutput = pipe
                process.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                        return
                    }
                    onOutput(text)
                }

                do {
                    try process.run()
                    onProcess(process)
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil

                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: DownloadServiceError.processFailed(status: process.terminationStatus))
                        return
                    }

                    let afterFiles = Self.snapshotFiles(in: destination)
                    let createdFiles = afterFiles.subtracting(beforeFiles).sorted { $0.lastPathComponent < $1.lastPathComponent }
                    continuation.resume(returning: DownloadResult(createdFiles: createdFiles))
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func snapshotFiles(in directory: URL) -> Set<URL> {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return Set(contents.filter { url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        })
    }
}
