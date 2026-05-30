@testable import LinkDownloader
import XCTest

final class ShellLocatorTests: XCTestCase {
    func testChildEnvironmentUsesWhitelist() {
        let environment = ShellLocator.environmentWithDefaultPath()
        let allowedKeys: Set<String> = [
            "PATH",
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

        XCTAssertTrue(Set(environment.keys).isSubset(of: allowedKeys))
        XCTAssertNotNil(environment["PATH"])
    }
}
