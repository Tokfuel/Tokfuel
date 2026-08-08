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

/// 固定日時（ローカルタイムゾーン）を作る。BudgetMonitor は Calendar.current の
/// タイムゾーンで日付文字列を作るため、テスト側も同じ前提で組み立てる。
private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

@MainActor
struct BudgetLevelTests {
    @Test func 上限未設定なら常にOK() {
        #expect(BudgetMonitor.level(spend: 999, limit: 0, warnPercent: 80) == .ok)
    }

    @Test func しきい値未満はOK() {
        #expect(BudgetMonitor.level(spend: 79.99, limit: 100, warnPercent: 80) == .ok)
    }

    @Test func しきい値ちょうどで警告() {
        #expect(BudgetMonitor.level(spend: 80, limit: 100, warnPercent: 80) == .warning)
    }

    @Test func 上限ちょうどで超過() {
        #expect(BudgetMonitor.level(spend: 100, limit: 100, warnPercent: 80) == .over)
    }

    @Test func レベルは順序比較できる() {
        #expect(BudgetLevel.ok < .warning)
        #expect(BudgetLevel.warning < .over)
    }
}

/// 使い捨ての UserDefaults スイート。重複抑止の状態は UserDefaults に載るので、
/// テストごとに独立したドメインを使い、実ユーザーの設定には触らない。
private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "tokfuel.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}

/// 知らせる手段の出し分け（TF #81）。選択と実行環境の組み合わせだけで決まり、
/// `BudgetMonitor` は `AppSettings` を読まない。
@MainActor
struct BudgetDeliveryTests {
    @Test func 通知を選ぶと通知だけ() {
        #expect(BudgetMonitor.delivery(for: .notification, notificationsAvailable: true)
                == BudgetMonitor.Delivery(notification: true, alertWindow: false))
    }

    @Test func アラートを選ぶとウィンドウだけ() {
        #expect(BudgetMonitor.delivery(for: .alert, notificationsAvailable: true)
                == BudgetMonitor.Delivery(notification: false, alertWindow: true))
    }

    @Test func 両方を選ぶと両方() {
        #expect(BudgetMonitor.delivery(for: .both, notificationsAvailable: true)
                == BudgetMonitor.Delivery(notification: true, alertWindow: true))
    }

    @Test func 通知が使えない環境では通知を落とす() {
        // 通知しか選んでいない人の挙動は黙って変えない（ウィンドウで代替しない）。
        #expect(BudgetMonitor.delivery(for: .notification, notificationsAvailable: false).isEmpty)
    }

    @Test func 通知が使えなくてもアラートは出す() {
        #expect(BudgetMonitor.delivery(for: .alert, notificationsAvailable: false)
                == BudgetMonitor.Delivery(notification: false, alertWindow: true))
        #expect(BudgetMonitor.delivery(for: .both, notificationsAvailable: false)
                == BudgetMonitor.Delivery(notification: false, alertWindow: true))
    }
}

/// 重複抑止（レベルが上がったときの 1 回だけ）。手段を変えても条件は同じ。
@MainActor
struct BudgetDeliveryIfNeededTests {
    private func delivery(_ level: BudgetLevel, periodKey: String = "2026-07",
                          style: BudgetAlertStyle = .both,
                          in defaults: UserDefaults) -> BudgetMonitor.Delivery? {
        BudgetMonitor.deliveryIfNeeded(kind: .monthly, level: level, periodKey: periodKey,
                                       style: style, notificationsAvailable: true,
                                       defaults: defaults)
    }

    @Test func 同じレベルの間は一度だけ知らせる() {
        withScratchDefaults { defaults in
            #expect(delivery(.warning, in: defaults)
                    == BudgetMonitor.Delivery(notification: true, alertWindow: true))
            #expect(delivery(.warning, in: defaults) == nil)
            #expect(delivery(.warning, in: defaults) == nil)
        }
    }

    @Test func レベルが上がったらもう一度知らせる() {
        withScratchDefaults { defaults in
            #expect(delivery(.warning, in: defaults) != nil)
            #expect(delivery(.over, in: defaults) != nil)
            #expect(delivery(.over, in: defaults) == nil)
        }
    }

    @Test func 期間が替わると再アームする() {
        withScratchDefaults { defaults in
            #expect(delivery(.warning, periodKey: "2026-07", in: defaults) != nil)
            #expect(delivery(.warning, periodKey: "2026-07", in: defaults) == nil)
            #expect(delivery(.warning, periodKey: "2026-08", in: defaults) != nil)
        }
    }

    @Test func 収まってから越え直すと再び知らせる() {
        withScratchDefaults { defaults in
            #expect(delivery(.over, in: defaults) != nil)
            #expect(delivery(.ok, in: defaults) == nil)
            #expect(delivery(.warning, in: defaults) != nil)
        }
    }

    @Test func 手段は引数の選択に従う() {
        withScratchDefaults { defaults in
            #expect(delivery(.warning, style: .alert, in: defaults)
                    == BudgetMonitor.Delivery(notification: false, alertWindow: true))
        }
        withScratchDefaults { defaults in
            #expect(delivery(.warning, style: .notification, in: defaults)
                    == BudgetMonitor.Delivery(notification: true, alertWindow: false))
        }
    }

    @Test func 出せる手段が無くても抑止状態は進める() {
        // 通知が使えない環境で「通知」を選んでいる場合。次のレベルまで何も出さない。
        withScratchDefaults { defaults in
            let first = BudgetMonitor.deliveryIfNeeded(
                level: .warning, periodKey: "2026-07", style: .notification,
                notificationsAvailable: false, defaults: defaults)
            #expect(first?.isEmpty == true)
            let second = BudgetMonitor.deliveryIfNeeded(
                level: .warning, periodKey: "2026-07", style: .notification,
                notificationsAvailable: false, defaults: defaults)
            #expect(second == nil)
        }
    }
}

/// 通知とアラートウィンドウが同じ文面を使う（経路で言い方が変わらない）。
@MainActor
struct BudgetMessageTests {
    @Test func OKのときは文面を作らない() {
        #expect(BudgetMonitor.message(kind: .monthly, level: .ok, spend: 10, limit: 100) == nil)
    }

    @Test func 日次は今日と分かる見出しになる() {
        let message = BudgetMonitor.message(kind: .daily, level: .over, spend: 25, limit: 20)
        #expect(message?.title.hasPrefix("今日の") == true)
    }

    @Test func 警告の本文に割合が入る() {
        let message = BudgetMonitor.message(kind: .monthly, level: .warning, spend: 250, limit: 300)
        #expect(message?.body.contains("83%") == true)
    }

    @Test func 割合は上限0でも落ちない() {
        #expect(BudgetMonitor.percent(spend: 10, limit: 0) == 0)
    }
}

@MainActor
struct BudgetPeriodTests {
    @Test func 暦月の起点は月初() {
        #expect(BudgetMonitor.periodStart(for: .calendarMonth, now: date(2026, 7, 28))
                == "2026-07-01")
    }

    @Test func ローリング30日の起点は29日前() {
        #expect(BudgetMonitor.periodStart(for: .rolling30, now: date(2026, 7, 30))
                == "2026-07-01")
    }

    @Test func ローリング30日は月をまたぐ() {
        #expect(BudgetMonitor.periodStart(for: .rolling30, now: date(2026, 7, 1))
                == "2026-06-02")
    }

    @Test func 暦月の通知キーは年月() {
        #expect(BudgetMonitor.periodKey(for: .calendarMonth, now: date(2026, 7, 28))
                == "2026-07")
    }

    @Test func 日次の通知キーはその日() {
        #expect(BudgetMonitor.dailyPeriodKey(now: date(2026, 7, 28)) == "2026-07-28")
    }
}
