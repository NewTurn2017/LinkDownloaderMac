// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LinkDownloader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LinkDownloader", targets: ["LinkDownloader"])
    ],
    targets: [
        .executableTarget(name: "LinkDownloader"),
        .testTarget(name: "LinkDownloaderTests", dependencies: ["LinkDownloader"])
    ]
)
