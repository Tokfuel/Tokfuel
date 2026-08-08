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
            path: "App/Tokfuel",
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
            path: "App/Tests",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // AX E2E ドライバ（標準 SDK の ApplicationServices のみ。Firebase 非依存）。
        .executableTarget(
            name: "TokfuelE2E",
            path: "App/E2E/Driver",
            // 複数 Swift ファイル + @main のため parse-as-library が必要。
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
