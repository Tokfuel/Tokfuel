import Foundation
import Testing
@testable import Tokfuel

/// 日別コストのフィクスチャ。
private func daily(_ pairs: [String: Double]) -> [String: RetokReport.DailyCost] {
    pairs.mapValues { RetokReport.DailyCost(cost: $0, output: 0) }
}

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

    private func report(daily costs: [String: Double]) -> RetokReport {
        RetokReport(
            periodDays: 30, filesScanned: 0, totals: .init(), cacheHitRate: 0,
            perModel: [:], daily: daily(costs), advice: [], topSessions: [])
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

    @Test func 二次ソースの今日ぶんはtodayCostに加算される() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4.56])
        store.driverDailyByID = ["cursor": [today: 1.44]]
        #expect(store.todayCost == 6.0)
    }

    @Test func 二次ソースは日付が一致しなければ加算されない() {
        let store = UsageStore()
        store.report = report(daily: [Self.dateString(Date()): 4.56])
        store.driverDailyByID = ["cursor": ["2020-01-01": 100]]
        #expect(store.todayCost == 4.56)
    }

    @Test func 複数の二次ソースは合算される() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.driverDailyByID = ["cursor": [today: 1.0], "other": [today: 2.0]]
        #expect(store.todayCost == 3.0)
    }

    @Test func driverDailyは全ソース横断で日別合算する() {
        let store = UsageStore()
        store.driverDailyByID = [
            "cursor": ["2026-01-01": 1.0, "2026-01-02": 2.0],
            "other": ["2026-01-01": 3.0]
        ]
        #expect(store.driverDaily["2026-01-01"] == 4.0)
        #expect(store.driverDaily["2026-01-02"] == 2.0)
    }

    @Test func driverBreakdownは今日ゼロのソースを出さない() {
        let store = UsageStore()
        store.driverDailyByID = ["cursor": ["2020-01-01": 5.0]]   // 今日ではない
        #expect(store.driverBreakdown.isEmpty)
    }

    @Test func driverBreakdownは今日ぶんの内訳を返す() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.driverDailyByID = ["cursor": [today: 3.1]]
        #expect(store.driverBreakdown.count == 1)
        #expect(store.driverBreakdown.first?.name == "Cursor")
        #expect(store.driverBreakdown.first?.cost == 3.1)
    }

    /// 追従モード（TF-0080）の入力。表示モードで合成する前の生の値をソース別に返す。
    @Test func todayCostBySourceはソース別の今日の額を返す() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4.5, "2020-01-01": 99])
        store.driverDailyByID = ["cursor": [today: 1.5], "codex": ["2020-01-01": 9]]
        let costs = store.todayCostBySource
        #expect(costs["claude"] == 4.5)
        #expect(costs["cursor"] == 1.5)
        // 今日ぶんが無いソースは 0。キーごと落とすと、次の集計で「新しいソース」と誤認される。
        #expect(costs["codex"] == 0)
    }

    /// 劣化中（TF-0073）の 0 は「使っていない」ではなく「取れなかった」。
    /// これを 0 として渡すと、復旧した瞬間の 0 → 実額を「使用中」と読んで追従モードに入る。
    @Test func todayCostBySourceは劣化したソースを外す() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4.5])
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.remoteUnavailable))
        ])
        let costs = store.todayCostBySource
        #expect(costs["claude"] == 4.5)
        #expect(costs["cursor"] == nil)

        // 取得できるようになったら、また比較対象に戻る。
        store.applyDriverSnapshots(["cursor": CostSnapshot(daily: [today: 1.5], byModel: [:])])
        #expect(store.todayCostBySource["cursor"] == 1.5)
    }

    @Test func 新しいスナップショットが空なら古いモデル内訳を消す() {
        let store = UsageStore()
        store.driverDailyByID = ["cursor": ["2026-07-30": 2]]
        store.driverModelByID = ["cursor": ["stale-model": 2]]

        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: ["2026-07-30": 1], byModel: [:])
        ])

        #expect(store.driverDailyByID["cursor"] == ["2026-07-30": 1])
        #expect(store.driverModelByID["cursor"]?.isEmpty == true)
    }
}

/// 二次ソースが「$0」なのか「取れなかった」のかを UI に伝える経路。
/// ここが黙って空辞書を返していたため、Cursor の使用量 API が止まった日に
/// 「Cursor を使っていない」と読める画面になっていた。
@MainActor
struct UsageStoreDegradedSourceTests {
    @Test func 劣化したソースは表示名と説明を返す() {
        let store = UsageStore()
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.remoteUnavailable))
        ])

        let warnings = store.degradedSourceWarnings
        #expect(warnings.count == 1)
        #expect(warnings.first?.name == "Cursor")
        #expect(warnings.first?.message == CostSnapshot.Degradation.remoteUnavailable.message)
        // 到達不能はサインインでは直らないので、ボタンを出さない。
        #expect(warnings.first?.signInBundleID == nil)
    }

    @Test func 認証拒否ならサインイン先を添える() {
        let store = UsageStore()
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.credentialsRejected))
        ])

        let warning = store.degradedSourceWarnings.first
        #expect(warning?.signInBundleID == CursorCostDriver().signInBundleID)
        #expect(warning?.signInBundleID != nil)
    }

    @Test func 未サインインもサインイン先を添える() {
        let store = UsageStore()
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:], health: .degraded(.signedOut))
        ])
        #expect(store.degradedSourceWarnings.first?.signInBundleID != nil)
    }

    @Test func 認証を持たないソースにはボタンを出さない() {
        // Codex は認証を持たない（signInBundleID の既定が nil）。
        let store = UsageStore(costDrivers: [CodexCostDriver()])
        store.applyDriverSnapshots([
            CodexCostDriver().id: CostSnapshot(daily: [:], byModel: [:],
                                              health: .degraded(.credentialsRejected))
        ])
        #expect(store.degradedSourceWarnings.first?.signInBundleID == nil)
    }

    @Test func 取得できたソースは注意書きを出さない() {
        let store = UsageStore()
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:])
        ])
        #expect(store.degradedSourceWarnings.isEmpty)
    }

    @Test func Claudeのみのモードでは出さない() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "degraded-\(UUID())")!)
        settings.costSourceMode = .claudeOnly
        let store = UsageStore(settings: settings)
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.remoteUnavailable))
        ])
        #expect(store.degradedSourceWarnings.isEmpty)
    }

    @Test func 劣化したソースは0円ではなく不明として並ぶ() {
        // 0 円と「取れなかった」を同じ見た目にしない（Issue の出発点そのもの）。
        let caption = PopoverView.sideBySideCaption(
            claudeCost: 12.34,
            driverBreakdown: [],
            unknownSources: ["Cursor"])
        #expect(caption.contains("Cursor —"))
        #expect(caption.contains("$0") == false)
    }

    @Test func Cursorのみのモードで劣化したら金額を出さない() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "unavailable-\(UUID())")!)
        settings.costSourceMode = .cursorOnly
        let store = UsageStore(settings: settings)
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.credentialsRejected))
        ])
        #expect(store.todayCostUnavailable)

        // 取れていれば通常表示に戻る。
        store.applyDriverSnapshots(["cursor": CostSnapshot(daily: [:], byModel: [:])])
        #expect(store.todayCostUnavailable == false)
    }

    @Test func 空のスナップショットは劣化状態も消す() {
        let store = UsageStore()
        store.driverHealthByID = ["cursor": .degraded(.signedOut)]
        store.applyDriverSnapshots([:])
        #expect(store.degradedSourceWarnings.isEmpty)
    }
}

/// メニューバーの割合表示の分母になる日次平均。
/// 使い始めた直後でも不当に小さくならないことが要点。
@MainActor
struct UsageStoreDailyAverageTests {
    @Test func 今日を除いた実績日の平均を返す() {
        let costs = daily(["2026-07-01": 2, "2026-07-02": 4, "2026-07-30": 100])
        #expect(UsageStore.dailyAverage(in: costs, since: "2026-06-30",
                                       before: "2026-07-30") == 3)
    }

    @Test func 期間の外は数えない() {
        let costs = daily(["2026-06-01": 100, "2026-07-01": 2, "2026-07-02": 4])
        #expect(UsageStore.dailyAverage(in: costs, since: "2026-06-30",
                                       before: "2026-07-30") == 3)
    }

    @Test func 記録の無い日は頭数に入れない() {
        // 3 日しか使っていないユーザーでも、30 で割らず 3 で割る。
        let costs = daily(["2026-07-01": 3, "2026-07-02": 3, "2026-07-03": 3])
        #expect(UsageStore.dailyAverage(in: costs, since: "2026-06-30",
                                       before: "2026-07-30") == 3)
    }

    @Test func 実績がなければゼロ() {
        #expect(UsageStore.dailyAverage(in: [:], since: "2026-06-30", before: "2026-07-30") == 0)
        #expect(UsageStore.dailyAverage(in: daily(["2026-07-01": 0]),
                                       since: "2026-06-30", before: "2026-07-30") == 0)
    }

    /// 稼働日数は平均と同じ「実績のある日」を数える。数え方がずれると、
    /// 平均 × 稼働日数で出す月側の分母が平常運転でも 100% に届かなくなる。
    @Test func 稼働日数は実績のある日だけを数える() {
        let costs = daily(["2026-06-30": 5, "2026-07-01": 2, "2026-07-02": 0, "2026-07-03": 4])
        #expect(UsageStore.activeDays(in: costs, since: "2026-07-01") == 2)
        #expect(UsageStore.activeDays(in: costs, since: "2026-06-30") == 3)
        #expect(UsageStore.activeDays(in: [:], since: "2026-07-01") == 0)
    }

    @Test func 稼働日数は今日を含める() {
        // 平均（今日を除く）と違い、こちらは「期間内にいくら使ったか」の相手なので今日も数える。
        let costs = daily(["2026-07-29": 3, "2026-07-30": 3])
        #expect(UsageStore.activeDays(in: costs, since: "2026-07-01") == 2)
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
