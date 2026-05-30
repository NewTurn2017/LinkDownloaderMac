import Foundation

struct DownloadOptions: Equatable {
    var extractMP3: Bool
    var includePlaylist: Bool

    static let standard = DownloadOptions(
        extractMP3: false,
        includePlaylist: false
    )
}
