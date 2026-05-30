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
    @Published var extractMP3: Bool {
        didSet { defaults.set(extractMP3, forKey: DefaultsKey.extractMP3) }
    }
    @Published var includePlaylist: Bool {
        didSet { defaults.set(includePlaylist, forKey: DefaultsKey.includePlaylist) }
    }
    @Published var revealWhenComplete: Bool {
        didSet { defaults.set(revealWhenComplete, forKey: DefaultsKey.revealWhenComplete) }
    }

    private let service = DownloadService()
    private var activeSession: DownloadSession?
    private var downloadTask: Task<Void, Never>?
    private var activeDownloadID: UUID?
    private let defaults = UserDefaults.standard

    init() {
        destinationURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        extractMP3 = defaults.bool(forKey: DefaultsKey.extractMP3)
        includePlaylist = defaults.bool(forKey: DefaultsKey.includePlaylist)
        revealWhenComplete = defaults.object(forKey: DefaultsKey.revealWhenComplete) as? Bool ?? true
        urlText = Self.clipboardURLString() ?? ""
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
        statusMessage = "다운로드 중"
        logText = ""
        lastDownloadedFile = nil

        let inputURL = urlText
        let targetDirectory = destinationURL
        let downloadID = UUID()
        let session = DownloadSession()

        activeDownloadID = downloadID
        activeSession = session

        downloadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await service.download(
                    urlString: inputURL,
                    destination: targetDirectory,
                    options: DownloadOptions(
                        extractMP3: extractMP3,
                        includePlaylist: includePlaylist
                    ),
                    session: session,
                    onOutput: { output in
                        Task { @MainActor in
                            if self.activeDownloadID == downloadID {
                                self.appendLog(output)
                            }
                        }
                    }
                )

                guard activeDownloadID == downloadID else { return }
                lastDownloadedFile = result.primaryFile
                statusMessage = session.isCancelled ? "중지됨" : result.primaryFile.map { "완료: \($0.lastPathComponent)" } ?? "완료"
                if !session.isCancelled, revealWhenComplete {
                    revealDestination()
                }
            } catch {
                guard activeDownloadID == downloadID else { return }
                statusMessage = session.isCancelled ? "중지됨" : error.localizedDescription
            }

            guard activeDownloadID == downloadID else { return }
            activeSession = nil
            activeDownloadID = nil
            downloadTask = nil
            isDownloading = false
        }
    }

    func cancelDownload() {
        activeSession?.cancel()
        statusMessage = "중지 중"
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

    private static func clipboardURLString() -> String? {
        guard let pasted = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: pasted),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return pasted
    }
}

private enum DefaultsKey {
    static let extractMP3 = "extractMP3"
    static let includePlaylist = "includePlaylist"
    static let revealWhenComplete = "revealWhenComplete"
}
