// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokfuelDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Demo-only exception for the #155 SwiftWasm spike. Not used by App/.
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "TokfuelDemo",
            dependencies: [
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            path: "Sources/TokfuelDemo"
        ),
    ]
)
