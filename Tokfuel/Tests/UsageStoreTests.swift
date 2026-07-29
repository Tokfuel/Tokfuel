import Foundation
import Testing
@testable import Tokfuel

/// `todayCost` は「不明」を返さない。レポート未取得も使っていない日も 0 として数える。
/// これでメニューバーの `bothCosts` 表示から金額が消えなくなる（Issue #4）。
@MainActor
struct UsageStoreTodayCostTests {
    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func report(daily: [String: Double]) -> RetokReport {
        RetokReport(
            periodDays: 30, filesScanned: 0, totals: .init(), cacheHitRate: 0,
            perModel: [:],
            daily: daily.mapValues { RetokReport.DailyCost(cost: $0, output: 0) },
            advice: [], topSessions: [])
    }

    @Test func レポート未取得でもゼロとして数える() {
        let store = UsageStore()
        #expect(store.todayCost == 0)
        #expect(store.budgetSpend == 0)
    }

    @Test func 使っていない日はゼロ() {
        let store = UsageStore()
        store.report = report(daily: ["2020-01-01": 1.23])   // 今日の行は無い
        #expect(store.todayCost == 0)
    }

    @Test func 今日の行があればその値を返す() {
        let store = UsageStore()
        store.report = report(daily: [Self.dateString(Date()): 4.56])
        #expect(store.todayCost == 4.56)
    }
}

/// デバッグ上書きが実データを置き換えるのは、スイッチが ON のときだけ。
@MainActor
struct DebugOverrideTests {
    @Test func オフなら上書きしない() {
        let debug = DebugSettings.shared
        debug.isActive = false
        #expect(debug.today == nil)
        #expect(debug.month == nil)
    }

    @Test func 今日の未取得の再現はレポートと今日のコストだけに効く() {
        let store = UsageStore()
        store.report = RetokReport(
            periodDays: 1, filesScanned: 0, totals: .init(), cacheHitRate: 0,
            perModel: [:], daily: [:], advice: [], topSessions: [])
        let debug = DebugSettings.shared
        debug.isActive = true
        debug.todayCost = 9
        debug.monthCost = 120
        debug.simulatesMissingReport = true

        #expect(store.report == nil)         // 推移・内訳は読み込み中表示に落ちる
        #expect(store.todayCost == 0)        // 金額上書きより未取得の再現が優先される
        #expect(store.budgetSpend == 120)    // 月側は別実行なので影響しない

        debug.simulatesMissingReport = false
        debug.isActive = false
    }

    @Test func 月だけ未取得の再現は今日を残す() {
        let store = UsageStore()
        let debug = DebugSettings.shared
        debug.isActive = true
        debug.todayCost = 9
        debug.simulatesMissingMonth = true

        #expect(store.todayCost == 9)
        #expect(store.budgetSpend == 0)

        debug.simulatesMissingMonth = false
        debug.isActive = false
    }

    @Test func オンなら設定した金額を返す() {
        let debug = DebugSettings.shared
        debug.isActive = true
        debug.todayCost = 1.5
        debug.monthCost = 99
        #expect(debug.today == 1.5)
        #expect(debug.month == 99)
        debug.isActive = false   // 共有インスタンスなので後続テストに漏らさない
    }
}
