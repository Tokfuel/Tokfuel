import Foundation
import TokfuelCore
import TokfuelSettings

public enum RemoteDiagnosticsPolicy {
    /// DEBUG や手元の `swift build` / `Scripts/build.sh` では false（開発中は Firebase を起動しない）。
    public static var isDistributionBuild: Bool {
        #if DEBUG
        return false
        #elseif TOKFUEL_DISTRIBUTION
        return true
        #else
        return false
        #endif
    }

    public static var enablesCrashlytics: Bool { isDistributionBuild }

    public static func enablesAnalytics(consent: Bool) -> Bool {
        isDistributionBuild && consent
    }

    public static let allowedEventNames: Set<String> = [
        "app_launch",
        "tab_open",
        "period_change",
        "settings_open",
        "setting_change",
        "notification_shown",
        "popover_open",
    ]

    public static let allowedMetaKeys: Set<String> = [
        "tab",
        "key",
        "kind",
        "period",
        "app_version",
        "macos_version",
    ]

    public static func sanitizedParameters(
        event: String,
        meta: [String: String]
    ) -> [String: String]? {
        guard allowedEventNames.contains(event) else { return nil }
        var out: [String: String] = [:]
        for (key, value) in meta where allowedMetaKeys.contains(key) {
            guard value.count <= 64, !value.contains("/"), !value.contains("\\") else { continue }
            out[key] = value
        }
        return out
    }
}
