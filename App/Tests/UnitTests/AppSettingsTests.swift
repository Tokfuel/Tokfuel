import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
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

    @Test func 外観モードの既定はシステムで永続化する() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.appearanceMode == .system)

        settings.appearanceMode = .dark
        #expect(defaults.string(forKey: "appearanceMode") == AppearanceMode.dark.rawValue)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.appearanceMode == .dark)
    }

    /// TF-0116: JPY で設定した上限額は、レートが更新されても勝手に変わらない
    /// （ネイティブ単位でそのまま保存し、時間経過だけでは再変換しない）。
    @Test func 円で設定した予算上限はレート更新後も変わらない() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(150.0, forKey: Money.rateKey)

        let settings = AppSettings(defaults: defaults)
        settings.displayCurrency = .jpy
        settings.budgetLimit = 5000
        settings.dailyBudgetLimit = 1000
        #expect(defaults.double(forKey: "budgetLimit") == 5000)

        // 為替レートが更新されたことを模す。
        defaults.set(151.2, forKey: Money.rateKey)
        #expect(settings.budgetLimit == 5000)
        #expect(settings.dailyBudgetLimit == 1000)
        #expect(defaults.double(forKey: "budgetLimit") == 5000)

        // USD 換算値（実際の判定用）は最新レートで計算される。
        #expect(settings.budgetLimitUSD == 5000 / 151.2)
    }

    /// 通貨を切り替えた瞬間だけ、上限額を新しい通貨のネイティブ単位へ変換する。
    @Test func 通貨切り替え時に予算上限を換算する() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(150.0, forKey: Money.rateKey)

        let settings = AppSettings(defaults: defaults)
        settings.budgetLimit = 30   // USD
        settings.displayCurrency = .jpy
        #expect(settings.budgetLimit == 4500)   // 30 * 150

        settings.displayCurrency = .usd
        #expect(settings.budgetLimit == 30)     // 4500 / 150 に戻る

        // 同じ通貨を選び直しても変換は起きない（不要な丸め誤差を防ぐ）。
        settings.displayCurrency = .usd
        #expect(settings.budgetLimit == 30)
    }

    /// レート未取得のまま通貨を切り替えても、値を確定保存してしまわない
    /// （後でレートが揃ったときに budgetLimitUSD が化けるのを防ぐ）。
    @Test func レート未取得での通貨切り替えは上限額を変えない() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        settings.budgetLimit = 30   // USD、レートは未取得のまま
        settings.displayCurrency = .jpy
        #expect(settings.budgetLimit == 30)

        // 後からレートが揃っても、既に切り替え済みの通貨には遡って適用されない。
        defaults.set(150.0, forKey: Money.rateKey)
        #expect(settings.budgetLimit == 30)
        #expect(settings.budgetLimitUSD == 30 / 150.0)
    }

    /// 旧バージョン（budgetLimit を常に USD で保存）からの一度きりの移行。
    @Test func 旧USD保存値をJPY表示なら一度だけネイティブ円へ移行する() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(DisplayCurrency.jpy.rawValue, forKey: Money.currencyKey)
        defaults.set(150.0, forKey: Money.rateKey)
        defaults.set(33.33, forKey: "budgetLimit")   // 旧バージョンが USD で保存した値

        let settings = AppSettings(defaults: defaults)
        #expect(settings.budgetLimit == (33.33 * 150).rounded())
        #expect(defaults.bool(forKey: "budgetLimitCurrencyMigrated"))

        // 二重変換されないことを確認する。
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.budgetLimit == settings.budgetLimit)
    }

    /// レート未取得のときは移行をスキップし、フラグも立てない（次回起動で再試行）。
    @Test func レート未取得のときは移行をスキップする() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(DisplayCurrency.jpy.rawValue, forKey: Money.currencyKey)
        defaults.set(33.33, forKey: "budgetLimit")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.budgetLimit == 33.33)
        #expect(!defaults.bool(forKey: "budgetLimitCurrencyMigrated"))
    }
}
