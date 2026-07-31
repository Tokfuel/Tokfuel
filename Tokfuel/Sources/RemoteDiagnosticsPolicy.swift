import Foundation

/// Firebase Crashlytics / Analytics を動かしてよいかの判定（#22）。
/// 送信そのものは `AnalyticsService` が担う。ここはゲート条件だけを置き、テスト可能にする。
enum RemoteDiagnosticsPolicy {
    /// 配布ビルド（`scripts/release.sh` が `-DTOKFUEL_DISTRIBUTION` を付けたもの）だけ true。
    /// DEBUG や手元の `swift build` / `scripts/build.sh` では false（開発中は Firebase を起動しない）。
    static var isDistributionBuild: Bool {
        #if DEBUG
        return false
        #elseif TOKFUEL_DISTRIBUTION
        return true
        #else
        return false
        #endif
    }

    /// Crashlytics: 配布ビルドなら同意なしで有効。
    static var enablesCrashlytics: Bool { isDistributionBuild }

    /// Analytics: 配布ビルドかつユーザー同意があるときだけ有効。
    static func enablesAnalytics(consent: Bool) -> Bool {
        isDistributionBuild && consent
    }

    /// Firebase へ載せてよいイベント名の許可リスト。ここに無い名前は送らない。
    static let allowedEventNames: Set<String> = [
        "app_launch",
        "tab_open",
        "period_change",
        "settings_open",
        "setting_change",
        "notification_shown",
        "popover_open",
    ]

    /// meta に載せてよいキー。コスト・パス・中身はここに入れない。
    static let allowedMetaKeys: Set<String> = [
        "tab",
        "key",
        "kind",
        "period",
        "app_version",
        "macos_version",
    ]

    /// 許可リストで meta を絞る。未知のイベント名なら nil。
    static func sanitizedParameters(
        event: String,
        meta: [String: String]
    ) -> [String: String]? {
        guard allowedEventNames.contains(event) else { return nil }
        var out: [String: String] = [:]
        for (key, value) in meta where allowedMetaKeys.contains(key) {
            // 値は短い識別子だけを想定。長すぎる・パスっぽいものは落とす。
            guard value.count <= 64, !value.contains("/"), !value.contains("\\") else { continue }
            out[key] = value
        }
        return out
    }
}
