import Foundation

enum ShellLocator {
    private static let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    static func findExecutable(named name: String) -> String? {
        for directory in defaultPath.split(separator: ":").map(String.init) {
            let candidate = "\(directory)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func environmentWithDefaultPath() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = defaultPath
        return environment
    }
}
