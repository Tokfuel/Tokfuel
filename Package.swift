// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tokfuel",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tokfuel",
            path: "Tokfuel/Sources",
            resources: [
                .copy("Resources/retok.py"),
                .copy("Resources/locales"),
                .copy("Resources/LICENSE-retok"),
                .copy("Resources/README-retok.md")
            ]
        ),
        .testTarget(
            name: "TokfuelTests",
            dependencies: ["Tokfuel"],
            path: "Tokfuel/Tests"
        )
    ]
)
