import Foundation
import Testing
@testable import Tokfuel

@MainActor
struct AppSettingsTests {
    @Test func ログイン時起動の変更を永続化する() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        settings.launchAtLogin = false
        #expect(defaults.bool(forKey: "launchAtLogin") == false)

        settings.launchAtLogin = true
        #expect(defaults.bool(forKey: "launchAtLogin") == true)
    }

    /// 追従モード（TF-0080）は未設定なら両方オン。bool(forKey:) が未設定を false と
    /// 読むので、既定オンの設定は存在確認を挟まないと黙ってオフで始まる。
    @Test func 追従モードの既定はオン() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.adaptiveRefreshEnabled)
        #expect(settings.activityAnimationEnabled)

        settings.adaptiveRefreshEnabled = false
        settings.activityAnimationEnabled = false
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.adaptiveRefreshEnabled == false)
        #expect(reloaded.activityAnimationEnabled == false)
    }
}
