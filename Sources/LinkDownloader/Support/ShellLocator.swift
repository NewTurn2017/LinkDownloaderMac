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
        let parentEnvironment = ProcessInfo.processInfo.environment
        var environment = ["PATH": defaultPath]
        let allowedKeys = [
            "HOME",
            "TMPDIR",
            "LANG",
            "LC_ALL",
            "LC_CTYPE",
            "SSL_CERT_FILE",
            "SSL_CERT_DIR",
            "XDG_CACHE_HOME",
            "XDG_CONFIG_HOME"
        ]

        for key in allowedKeys {
            if let value = parentEnvironment[key] {
                environment[key] = value
            }
        }

        return environment
    }
}
