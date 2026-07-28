import Foundation
import Testing
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
