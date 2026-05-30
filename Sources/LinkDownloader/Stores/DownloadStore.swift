import AppKit
import Combine
import Foundation

@MainActor
final class DownloadStore: ObservableObject {
    @Published var urlText = ""
    @Published var destinationURL: URL
    @Published var isDownloading = false
    @Published var statusMessage = "대기 중"
    @Published var logText = ""
    @Published var lastDownloadedFile: URL?

    private let service = DownloadService()
    private var activeProcess: Process?
    private var downloadTask: Task<Void, Never>?
    private var didRequestCancel = false

    init() {
        destinationURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    var canStart: Bool {
        !isDownloading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func pasteFromClipboard() {
        if let pasted = NSPasteboard.general.string(forType: .string) {
            urlText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func selectDestination() {
        let panel = NSOpenPanel()
        panel.title = "저장 위치 선택"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL

        if panel.runModal() == .OK, let selectedURL = panel.url {
            destinationURL = selectedURL
        }
    }

    func startDownload() {
        guard canStart else { return }

        isDownloading = true
        didRequestCancel = false
        statusMessage = "다운로드 중"
        logText = ""
        lastDownloadedFile = nil

        let inputURL = urlText
        let targetDirectory = destinationURL

        downloadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await service.download(
                    urlString: inputURL,
                    destination: targetDirectory,
                    onProcess: { process in
                        Task { @MainActor in
                            self.activeProcess = process
                        }
                    },
                    onOutput: { output in
                        Task { @MainActor in
                            self.appendLog(output)
                        }
                    }
                )

                lastDownloadedFile = result.primaryFile
                statusMessage = didRequestCancel ? "중지됨" : result.primaryFile.map { "완료: \($0.lastPathComponent)" } ?? "완료"
            } catch {
                statusMessage = didRequestCancel ? "중지됨" : error.localizedDescription
            }

            activeProcess = nil
            isDownloading = false
        }
    }

    func cancelDownload() {
        didRequestCancel = true
        activeProcess?.terminate()
        downloadTask?.cancel()
        activeProcess = nil
        isDownloading = false
        statusMessage = "중지됨"
    }

    func revealDestination() {
        if let lastDownloadedFile {
            NSWorkspace.shared.activateFileViewerSelecting([lastDownloadedFile])
        } else {
            NSWorkspace.shared.open(destinationURL)
        }
    }

    private func appendLog(_ text: String) {
        logText += text
        if logText.count > 20_000 {
            logText = String(logText.suffix(20_000))
        }
    }
}
