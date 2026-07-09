// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeUsageMenubar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageMenubar",
            path: "ClaudeUsageMenubar/Sources",
            resources: [
                .copy("Resources/retok.py"),
                .copy("Resources/locales"),
                .copy("Resources/LICENSE-retok"),
                .copy("Resources/README-retok.md")
            ]
        )
    ]
)
