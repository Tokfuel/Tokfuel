#if DEBUG
import Foundation
import TokfuelStore
import TokfuelUI

/// AX E2E（`--e2e-fixture` / `--e2e-fixture=<profile>`）用の起動準備。
/// 実ユーザーの Application Support は触らず、`ScreenshotRenderer` と同じフィクスチャを載せる。
@MainActor
enum E2EFixture {
    static var isEnabled: Bool {
        CommandLine.arguments.contains { $0 == "--e2e-fixture" || $0.hasPrefix("--e2e-fixture=") }
    }

    static var profile: E2EFixtureProfile {
        E2EFixtureProfile.resolve(from: CommandLine.arguments)
    }

    static func prepareLaunch() {
        ScreenshotRenderer.applyE2ELaunchDefaults(profile: profile.rawValue)
    }

    static func seed(_ store: UsageStore) {
        ScreenshotRenderer.seedE2EStore(store, profile: profile.rawValue)
        store.freezeNetworkIO = true
    }
}

/// シナリオ群ごとのフィクスチャ状態。起動引数 `--e2e-fixture=<rawValue>` で選ぶ。
enum E2EFixtureProfile: String, CaseIterable {
    case `default`
    case jpy
    case claudeOnly
    case combined
    case cursorOnly
    case sideBySide
    case light
    case advancedOpen
    case debugOpen
    case budgetWarn
    case budgetOver
    case cursorDegraded
    case cursorSignIn
    case updateAvailable
    case sessions
    case cumulative
    case analyticsConsent

    static func resolve(from args: [String]) -> E2EFixtureProfile {
        if let flag = args.first(where: { $0.hasPrefix("--e2e-fixture=") }) {
            let raw = String(flag.dropFirst("--e2e-fixture=".count))
            return E2EFixtureProfile(rawValue: raw) ?? .default
        }
        return .default
    }
}
#endif
