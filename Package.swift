// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tokfuel",
    platforms: [.macOS(.v14)],
    dependencies: [
        // #22: オーナー承認の例外。Analytics + Crashlytics のみ。
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "Tokfuel",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
            path: "Tokfuel/Sources",
            resources: [
                .copy("Resources/retok.py"),
                .copy("Resources/locales"),
                .copy("Resources/LICENSE-retok"),
                .copy("Resources/README-retok.md"),
                .copy("Resources/GoogleService-Info.plist")
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "TokfuelTests",
            dependencies: ["Tokfuel"],
            path: "Tokfuel/Tests",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
