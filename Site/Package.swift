// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Site",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/twostraws/Ignite", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Site",
            dependencies: [
                .product(name: "Ignite", package: "Ignite")
            ],
            path: "Sources/Site"
        )
    ]
)
