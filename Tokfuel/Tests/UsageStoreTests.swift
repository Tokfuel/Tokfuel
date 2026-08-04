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

/// 金額が付かない使用（#91 の金額不明・#100 のプラン枠内）を UI が書き分けるための経路。
@MainActor
struct UsageStoreUnbilledUsageTests {
    private static func dateString(_ date: Date) -> String { UsageStore.dateString(date) }

    private func snapshot(
        today: Double = 0,
        unbilled: [String: Int] = [:],
        unpriced: [String: Int] = [:]
    ) -> CostSnapshot {
        let today0 = Self.dateString(Date())
        return CostSnapshot(
            daily: [today0: today],
            byModel: [:],
            unbilled: CostSnapshot.UnbilledUsage(tokensByModel: unbilled,
                                                days: unbilled.isEmpty ? [] : [today0]),
            unpriced: CostSnapshot.UnbilledUsage(tokensByModel: unpriced,
                                                days: unpriced.isEmpty ? [] : [today0]))
    }

    @Test func プラン枠内の利用は補足として出す() {
        let store = UsageStore()
        store.applyDriverSnapshots([
            "cursor": snapshot(unbilled: ["cursor-grok-4.5-high-fast": 574_362])
        ])
        let notice = store.unbilledSourceNotices.first
        #expect(store.unbilledSourceNotices.count == 1)
        #expect(notice?.name == "Cursor")
        #expect(notice?.message.contains("cursor-grok-4.5-high-fast") == true)
        // 金額そのものは正しい 0 なので、金額を伏せる側（—）には回さない。
        #expect(store.unpricedSourceNotices.isEmpty)
        #expect(store.unknownSourceNames.isEmpty)
    }

    @Test func 金額不明の利用は警告として出す() {
        let store = UsageStore()
        store.applyDriverSnapshots(["cursor": snapshot(unpriced: ["composer-2.5-fast": 500])])
        let notice = store.unpricedSourceNotices.first
        #expect(notice?.name == "Cursor")
        #expect(notice?.message.contains("composer-2.5-fast") == true)
        #expect(store.unbilledSourceNotices.isEmpty)
    }

    @Test func モデルが多いときは畳んで1行に収める() {
        #expect(UsageStore.modelList(["a", "b"]) == "a, b")
        #expect(UsageStore.modelList(["a", "b", "c", "d"]) == "a, b ほか 2 件")
    }

    @Test func Cursorのみで金額不明しか無ければ金額を伏せる() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "unpriced-\(UUID())")!)
        settings.costSourceMode = .cursorOnly
        let store = UsageStore(settings: settings)
        store.applyDriverSnapshots(["cursor": snapshot(unpriced: ["composer-2.5-fast": 500])])
        #expect(store.todayCostUnavailable)
        #expect(store.unknownSourceNames == ["Cursor"])

        // プラン枠内だけの日は「本当に $0」なので、金額はそのまま出す。
        store.applyDriverSnapshots([
            "cursor": snapshot(unbilled: ["cursor-grok-4.5-high-fast": 1_000])
        ])
        #expect(store.todayCostUnavailable == false)

        // 金額不明のイベントがあっても、請求される利用が乗っている日は金額を出す。
        store.applyDriverSnapshots([
            "cursor": snapshot(today: 1.5, unpriced: ["composer-2.5-fast": 500])
        ])
        #expect(store.todayCostUnavailable == false)
    }

    @Test func 空のスナップショットは記録も消す() {
        let store = UsageStore()
        store.applyDriverSnapshots(["cursor": snapshot(unpriced: ["composer-2.5-fast": 500])])
        store.applyDriverSnapshots(["cursor": CostSnapshot(daily: [:], byModel: [:])])
        #expect(store.unpricedSourceNotices.isEmpty)
        #expect(store.unbilledSourceNotices.isEmpty)
    }
}

/// 「高コストのセッション」の Claude / 二次ソースのマージ（TF-0077）。
@MainActor
struct UsageStoreTopSessionTests {
    private func report(_ sessions: [(String, String, Double)]) -> RetokReport {
        RetokReport(
            periodDays: 30, filesScanned: 0, totals: .init(), cacheHitRate: 0,
            perModel: [:], daily: [:], advice: [],
            topSessions: sessions.map {
                RetokReport.TopSession(session: $0.0, project: $0.1, cost: $0.2,
                                       prompts: 1, maxContext: 1)
            })
    }

    private func session(_ id: String, _ title: String, _ cost: Double) -> CostSnapshot.Session {
        CostSnapshot.Session(id: id, title: title, cost: cost, messages: 1,
                             lastUsed: "2026-07-30")
    }

    /// 共有設定を汚さないよう、テストごとに専用の UserDefaults スイートで store を作る。
    private func store(mode: CostSourceMode) -> UsageStore {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "top-sessions-\(UUID())")!)
        settings.costSourceMode = mode
        return UsageStore(settings: settings)
    }

    @Test func コスト降順にマージして上位3件だけ出す() {
        let store = store(mode: .combined)
        let report = report([("s1", "claude-a", 18.0), ("s2", "claude-b", 4.0)])
        store.driverSessionsByID = ["cursor": [session("c1", "cursor-a", 11.0),
                                               session("c2", "cursor-b", 1.0)]]

        let rows = store.topSessionRows(for: report)
        #expect(rows.map(\.title) == ["claude-a", "cursor-a", "claude-b"])
        #expect(rows.map(\.source) == ["Claude", "Cursor", "Claude"])
        #expect(rows.map(\.isEstimated) == [false, true, false])
    }

    @Test func claudeのみのモードではCursorの行を出さない() {
        let report = report([("s1", "claude-a", 4.0)])
        let sessions = ["cursor": [session("c1", "cursor-a", 11.0)]]

        let claudeOnly = store(mode: .claudeOnly)
        claudeOnly.driverSessionsByID = sessions
        #expect(claudeOnly.topSessionRows(for: report).map(\.title) == ["claude-a"])

        let cursorOnly = store(mode: .cursorOnly)
        cursorOnly.driverSessionsByID = sessions
        #expect(cursorOnly.topSessionRows(for: report).map(\.title) == ["cursor-a"])
    }

    /// ローカル走査が空になる環境（#73）では Cursor 行が増えないだけで、$0 の行は並ばない。
    @Test func 二次ソースが空なら行は増えない() {
        let store = store(mode: .combined)
        #expect(store.topSessionRows(for: report([("s1", "claude-a", 4.0)])).count == 1)
    }

    @Test func 両ソースとも空なら行が無くセクションは消える() {
        #expect(store(mode: .combined).topSessionRows(for: report([])).isEmpty)
    }

    @Test func ゼロ円のセッションは並べない() {
        let store = store(mode: .combined)
        store.driverSessionsByID = ["cursor": [session("c1", "cursor-zero", 0)]]
        #expect(store.topSessionRows(for: report([("s1", "claude-a", 4.0)])).map(\.title)
                == ["claude-a"])
    }

    @Test func 同額でも並びが揺れない() {
        let store = store(mode: .combined)
        let report = report([("s1", "claude-a", 5.0)])
        store.driverSessionsByID = ["cursor": [session("c1", "cursor-a", 5.0)]]

        let first = store.topSessionRows(for: report).map(\.id)
        for _ in 0..<20 {
            #expect(store.topSessionRows(for: report).map(\.id) == first)
        }
    }

    @Test func 新しい取得結果で古い会話を置き換える() {
        let store = UsageStore()
        store.driverSessionsByID = ["cursor": [session("stale", "古い会話", 9)]]
        store.applyDriverSessions([:])
        #expect(store.driverSessionsByID.isEmpty)
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
