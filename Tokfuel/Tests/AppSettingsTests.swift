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
}
