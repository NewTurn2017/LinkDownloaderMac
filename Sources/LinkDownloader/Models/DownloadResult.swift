import Foundation

struct DownloadResult {
    let createdFiles: [URL]

    var primaryFile: URL? {
        createdFiles.first { $0.pathExtension.lowercased() == "mp4" } ?? createdFiles.first
    }
}

enum DownloadServiceError: LocalizedError {
    case invalidURL
    case missingYTDLP
    case missingFFmpeg
    case processFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "올바른 http 또는 https 주소를 입력하세요."
        case .missingYTDLP:
            return "yt-dlp를 찾을 수 없습니다. Homebrew로 yt-dlp를 설치한 뒤 다시 실행하세요."
        case .missingFFmpeg:
            return "ffmpeg를 찾을 수 없습니다. MP4 변환과 MP3 추출을 위해 ffmpeg를 설치하세요."
        case .processFailed(let status):
            return "다운로드 명령이 실패했습니다. 종료 코드: \(status)"
        }
    }
}
