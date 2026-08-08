// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tokfuel",
    platforms: [.macOS(.v14)],
    dependencies: [
        // #22: オーナー承認の例外。Analytics + Crashlytics のみ。
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.15.0"),
        // オーナー承認の例外。テスト専用の VRT（Point-Free SnapshotTesting）。
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
    ],
    targets: [
        .target(
            name: "TokfuelCore",
            path: "App/TokfuelCore"
        ),
        .target(
            name: "TokfuelSettings",
            dependencies: ["TokfuelCore"],
            path: "App/TokfuelSettings"
        ),
        .target(
            name: "TokfuelClaude",
            dependencies: ["TokfuelCore"],
            path: "App/TokfuelClaude",
            resources: [
                .copy("Resources/retok.py"),
                .copy("Resources/locales"),
                .copy("Resources/LICENSE-retok"),
                .copy("Resources/README-retok.md"),
            ]
        ),
        .target(
            name: "TokfuelCursor",
            dependencies: ["TokfuelCore"],
            path: "App/TokfuelCursor",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "TokfuelCodex",
            dependencies: ["TokfuelCore", "TokfuelClaude"],
            path: "App/TokfuelCodex"
        ),
        .target(
            name: "TokfuelBudget",
            dependencies: ["TokfuelCore", "TokfuelSettings"],
            path: "App/TokfuelBudget"
        ),
        .target(
            name: "TokfuelAnalytics",
            dependencies: [
                "TokfuelCore",
                "TokfuelSettings",
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
            path: "App/TokfuelAnalytics",
            resources: [
                .copy("Resources/GoogleService-Info.plist"),
            ]
        ),
        .target(
            name: "TokfuelStore",
            dependencies: [
                "TokfuelCore",
                "TokfuelSettings",
                "TokfuelClaude",
                "TokfuelCursor",
                "TokfuelCodex",
                "TokfuelBudget",
            ],
            path: "App/TokfuelStore"
        ),
        .target(
            name: "TokfuelUI",
            dependencies: [
                "TokfuelCore",
                "TokfuelSettings",
                "TokfuelStore",
                "TokfuelBudget",
                "TokfuelAnalytics",
                "TokfuelClaude",
                "TokfuelCursor",
            ],
            path: "App/TokfuelUI"
        ),
        .executableTarget(
            name: "Tokfuel",
            dependencies: [
                "TokfuelCore",
                "TokfuelSettings",
                "TokfuelClaude",
                "TokfuelCursor",
                "TokfuelCodex",
                "TokfuelBudget",
                "TokfuelAnalytics",
                "TokfuelStore",
                "TokfuelUI",
            ],
            path: "App/Tokfuel"
        ),
        // AX E2E ドライバ（標準 SDK の ApplicationServices のみ。Firebase 非依存）。
        .executableTarget(
            name: "TokfuelE2E",
            path: "App/Tests/E2E/Driver",
            // 複数 Swift ファイル + @main のため parse-as-library が必要。
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(
            name: "TokfuelTests",
            dependencies: [
                "Tokfuel",
                "TokfuelCore",
                "TokfuelSettings",
                "TokfuelClaude",
                "TokfuelCursor",
                "TokfuelCodex",
                "TokfuelBudget",
                "TokfuelAnalytics",
                "TokfuelStore",
                "TokfuelUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "App/Tests/UnitTests",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
