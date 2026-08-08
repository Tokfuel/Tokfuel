// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokfuelDemo",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "DemoUI", targets: ["DemoUI"]),
        .executable(name: "TokfuelDemo", targets: ["TokfuelDemo"]),
    ],
    dependencies: [
        // Demo-only. Not used by the App package.
        // Upstream TokamakDOM does not yet build cleanly on Swift 6.2 wasip1
        // (CoreFoundation / OpenCombineJS). We ship a local TokamakDOM-shaped
        // shim that renders View trees via JavaScriptKit so DemoUI stays the
        // SwiftUI-shaped source of truth.
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.21.0"),
    ],
    targets: [
        .target(
            name: "TokamakDOM",
            dependencies: [
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            path: "DemoSwiftUI"
        ),
        .target(
            name: "DemoUI",
            dependencies: ["TokamakDOM"],
            path: "DemoUI"
        ),
        .executableTarget(
            name: "TokfuelDemo",
            dependencies: [
                "DemoUI",
                "TokamakDOM",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            path: "wasm/Sources/TokfuelDemo"
        ),
    ]
)
