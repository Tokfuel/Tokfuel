import Foundation
import Testing
@testable import Tokfuel

@Suite struct CostDisplayModeTests {
    private static let bySource = ["claude": 4.0, "cursor": 2.0, "codex": 1.0]

    @Test func displayedSpendはモードごとに合成する() {
        let spend = Self.bySource
        #expect(UsageStore.displayedSpend(bySource: spend, mode: .combined) == 7)
        #expect(UsageStore.displayedSpend(bySource: spend, mode: .sideBySide) == 7)
        #expect(UsageStore.displayedSpend(bySource: spend, mode: .claudeOnly) == 4)
        #expect(UsageStore.displayedSpend(bySource: spend, mode: .cursorOnly) == 2)
        #expect(UsageStore.displayedSpend(bySource: spend, mode: .codexOnly) == 1)
    }

    @Test func includesはソースid単位で判定する() {
        #expect(CostSourceMode.sideBySide.includes(sourceID: "claude"))
        #expect(CostSourceMode.sideBySide.includes(sourceID: "cursor"))
        #expect(CostSourceMode.sideBySide.includes(sourceID: "codex"))
        #expect(!CostSourceMode.claudeOnly.includes(sourceID: "cursor"))
        #expect(!CostSourceMode.claudeOnly.includes(sourceID: "codex"))
        #expect(!CostSourceMode.cursorOnly.includes(sourceID: "claude"))
        #expect(!CostSourceMode.cursorOnly.includes(sourceID: "codex"))
        #expect(CostSourceMode.codexOnly.includes(sourceID: "codex"))
        #expect(!CostSourceMode.codexOnly.includes(sourceID: "claude"))
        #expect(!CostSourceMode.codexOnly.includes(sourceID: "cursor"))
        // 未知のドライバが増えても、合算には入り「◯◯ のみ」には混ざらない。
        #expect(CostSourceMode.combined.includes(sourceID: "gemini"))
        #expect(!CostSourceMode.cursorOnly.includes(sourceID: "gemini"))
    }

    @Test func Codex未インストールなら選択肢から外す() {
        #expect(CostSourceMode.available(codexInstalled: true).contains(.codexOnly))
        #expect(!CostSourceMode.available(codexInstalled: false).contains(.codexOnly))
        // 他の選択肢は減らさない。
        #expect(CostSourceMode.available(codexInstalled: false).count
                == CostSourceMode.allCases.count - 1)
        #expect(CostSourceMode.resolved(.codexOnly, codexInstalled: false) == .combined)
        #expect(CostSourceMode.resolved(.codexOnly, codexInstalled: true) == .codexOnly)
        #expect(CostSourceMode.resolved(.cursorOnly, codexInstalled: false) == .cursorOnly)
    }
}

@MainActor
struct CostSourceModeSettingsTests {
    /// 保存済みの `codexOnly` は、Codex が消えた Mac では合算として読み込む。
    @Test func 保存済みのCodexのみは未インストールなら合算へ落ちる() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(CostSourceMode.codexOnly.rawValue, forKey: "costSourceMode")

        #expect(AppSettings(defaults: defaults, codexInstalled: false).costSourceMode == .combined)
        #expect(AppSettings(defaults: defaults, codexInstalled: true).costSourceMode == .codexOnly)
        // 保存値そのものは書き換えない（Codex が戻れば選択も戻る）。
        #expect(defaults.string(forKey: "costSourceMode") == CostSourceMode.codexOnly.rawValue)
    }

    @Test func ピッカーの選択肢はCodexの有無で変わる() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let without = AppSettings(defaults: defaults, codexInstalled: false)
        #expect(!without.availableCostSourceModes.contains(.codexOnly))
        let with = AppSettings(defaults: defaults, codexInstalled: true)
        #expect(with.availableCostSourceModes.contains(.codexOnly))
    }
}

@MainActor
struct CostSourceModeUsageStoreTests {
    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func report(daily costs: [String: Double],
                        models: [String: Double] = [:]) -> RetokReport {
        RetokReport(
            periodDays: 30, filesScanned: 0, totals: .init(cost: costs.values.reduce(0, +)),
            cacheHitRate: 0,
            perModel: models.mapValues {
                RetokReport.ModelUsage(cost: $0, input: 0, output: 0, requests: 0)
            },
            daily: costs.mapValues { RetokReport.DailyCost(cost: $0, output: 0) },
            advice: [], topSessions: [])
    }

    /// UserDefaults に残る設定を汚染しないよう、必ず元へ戻す。
    private func withSourceMode<T>(_ mode: CostSourceMode, _ body: () -> T) -> T {
        let settings = AppSettings.shared
        let previous = settings.costSourceMode
        settings.costSourceMode = mode
        defer { settings.costSourceMode = previous }
        return body()
    }

    private func withModelBreakdown<T>(_ mode: CostModelBreakdownMode, _ body: () -> T) -> T {
        let settings = AppSettings.shared
        let previous = settings.costModelBreakdownMode
        settings.costModelBreakdownMode = mode
        defer { settings.costModelBreakdownMode = previous }
        return body()
    }

    @Test func todayCostはソースモードでフィルタする() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2]]

        withSourceMode(.combined) { #expect(store.todayCost == 6) }
        withSourceMode(.claudeOnly) { #expect(store.todayCost == 4) }
        withSourceMode(.cursorOnly) { #expect(store.todayCost == 2) }
        withSourceMode(.sideBySide) { #expect(store.todayCost == 6) }
    }

    @Test func todayCostはCodexを単独で出せる() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2], "codex": [today: 1]]

        withSourceMode(.combined) { #expect(store.todayCost == 7) }
        withSourceMode(.codexOnly) { #expect(store.todayCost == 1) }
        withSourceMode(.cursorOnly) { #expect(store.todayCost == 2) }
        withSourceMode(.claudeOnly) { #expect(store.todayCost == 4) }
        // 並べて表示の Cursor 側は二次ソース合計のまま（この Issue では拡張しない）。
        #expect(store.secondaryTodayCost == 3)
        #expect(store.todayCost(forSource: CostSourceMode.codexSourceID) == 1)
    }

    /// Codex 未インストール（driverDailyByID に codex が無い）なら「Codex のみ」は $0。
    @Test func Codexのデータが無ければCodexのみは0になる() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2]]

        withSourceMode(.codexOnly) {
            #expect(store.todayCost == 0)
            #expect(store.periodTotalCost(for: store.report!) == 0)
            #expect(store.chartRows(for: store.report!).isEmpty)
        }
    }

    @Test func 予算の消費もソースモードで合成する() {
        let store = UsageStore()
        store.setBudgetSpend(bySource: ["claude": 40, "cursor": 20, "codex": 10])

        withSourceMode(.combined) { #expect(store.budgetSpend == 70) }
        withSourceMode(.claudeOnly) { #expect(store.budgetSpend == 40) }
        withSourceMode(.cursorOnly) { #expect(store.budgetSpend == 20) }
        withSourceMode(.codexOnly) { #expect(store.budgetSpend == 10) }
        // 予算の分母（settings.budgetLimit）は変わらず、消費だけが選んだソースぶんになる。
        #expect(store.claudeBudgetSpend == 40)
        #expect(store.secondaryBudgetSpend == 30)
    }

    /// 劣化警告と「金額が取れていない」は、表示対象に入っているドライバだけを見る。
    @Test func 劣化警告は表示対象のソースだけ出す() {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults, codexInstalled: true)
        let store = UsageStore(settings: settings)
        let today = Self.dateString(Date())
        store.applyDriverSnapshots([
            "cursor": CostSnapshot(daily: [:], byModel: [:],
                                   health: .degraded(.remoteUnavailable)),
            "codex": CostSnapshot(daily: [today: 1], byModel: [:])
        ])

        // Codex は劣化していないので、Cursor の注意書きは出さないし金額も隠さない。
        settings.costSourceMode = .codexOnly
        #expect(store.degradedSourceWarnings.isEmpty)
        #expect(store.todayCostUnavailable == false)
        #expect(store.todayCost == 1)

        settings.costSourceMode = .cursorOnly
        #expect(store.degradedSourceWarnings.map(\.id) == ["cursor"])
        #expect(store.todayCostUnavailable)

        // Claude を含むモードは注意書きだけ出し、金額は隠さない（retok 側のエラー行が担う）。
        settings.costSourceMode = .combined
        #expect(store.degradedSourceWarnings.map(\.id) == ["cursor"])
        #expect(store.todayCostUnavailable == false)
    }

    @Test func chartRowsはCodexのみでCodex系列だけ出す() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2], "codex": [today: 1]]

        withSourceMode(.codexOnly) {
            let rows = store.chartRows(for: store.report!)
            #expect(rows.count == 1)
            #expect(rows.first?.source == "Codex")
            #expect(rows.first?.cost == 1)
        }
    }

    @Test func periodTotalCostはソースモードでフィルタする() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2], "codex": [today: 1]]

        withSourceMode(.combined) { #expect(store.periodTotalCost(for: store.report!) == 7) }
        withSourceMode(.codexOnly) { #expect(store.periodTotalCost(for: store.report!) == 1) }
        withSourceMode(.claudeOnly) { #expect(store.periodTotalCost(for: store.report!) == 4) }
    }

    @Test func chartRowsはソースモードで系列を絞る() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2]]

        withSourceMode(.claudeOnly) {
            let rows = store.chartRows(for: store.report!)
            #expect(rows.count == 1)
            #expect(rows.first?.source == UsageStore.claudeSourceLabel)
        }
        withSourceMode(.cursorOnly) {
            let rows = store.chartRows(for: store.report!)
            #expect(rows.count == 1)
            #expect(rows.first?.source == "Cursor")
        }
        withSourceMode(.combined) {
            #expect(store.chartRows(for: store.report!).count == 2)
        }
    }

    @Test func chartRowsは二次ソースをdriverごとに別系列にする() {
        let store = UsageStore()
        let today = Self.dateString(Date())
        store.report = report(daily: [today: 4])
        store.driverDailyByID = ["cursor": [today: 2], "codex": [today: 1]]

        withSourceMode(.combined) {
            let rows = store.chartRows(for: store.report!)
            let sources = Set(rows.map(\.source))
            #expect(sources == [UsageStore.claudeSourceLabel, "Cursor", "Codex"])
            #expect(rows.first { $0.source == "Cursor" }?.cost == 2)
            #expect(rows.first { $0.source == "Codex" }?.cost == 1)
        }
    }

    @Test func sideBySideCaptionは0円のドライバーを省く() {
        let caption = PopoverView.sideBySideCaption(
            claudeCost: 4, driverBreakdown: [("Cursor", 2), ("Codex", 0)])
        #expect(caption.contains("Cursor"))
        #expect(!caption.contains("Codex"))
        #expect(!caption.contains("その他"))
    }

    @Test func modelCostRowsは結合と分離を切り替える() {
        let store = UsageStore()
        store.report = report(daily: [:], models: ["claude-sonnet": 3])
        store.driverModelByID = ["cursor": ["gpt-5": 1]]

        withSourceMode(.combined) {
            withModelBreakdown(.combined) {
                let rows = store.modelCostRows(for: store.report!)
                #expect(rows.count == 2)
                #expect(rows.allSatisfy { $0.source == nil })
            }
            withModelBreakdown(.separated) {
                let rows = store.modelCostRows(for: store.report!)
                #expect(rows.count == 2)
                #expect(rows.contains { $0.source == UsageStore.claudeSourceLabel })
                #expect(rows.contains { $0.source == "Cursor" })
            }
        }
        withSourceMode(.cursorOnly) {
            withModelBreakdown(.combined) {
                let rows = store.modelCostRows(for: store.report!)
                #expect(rows.count == 1)
                #expect(rows.first?.model == "gpt-5")
            }
        }
        // Codex はモデル別内訳を持たないので、セクションごと空になる。
        withSourceMode(.codexOnly) {
            withModelBreakdown(.combined) {
                #expect(store.modelCostRows(for: store.report!).isEmpty)
            }
        }
    }
}

@Suite struct MenuBarSideBySideTests {
    @Test func 並べて表示の金額タイトルは両ソースを出す() {
        let input = MenuBarInput(
            metric: .today, representation: .amount, costSourceMode: .sideBySide,
            gauge: MenuBarGauge(todaySpend: 6, todayBasis: 0, monthSpend: 0, monthBasis: 0),
            todayClaude: 4, todayCursor: 2)
        let content = MenuBarReadout.content(for: input)
        #expect(content.title.contains("Claude"))
        #expect(content.title.contains("Cursor"))
        #expect(content.title.contains(Money.format(4)))
        #expect(content.title.contains(Money.format(2)))
    }

    /// 取得できていない Cursor を 0 円として出すと「使っていない」と読めてしまう。
    /// メニューバーはポップオーバーより情報量が少ないぶん、この誤読が起きやすい。
    @Test func Cursorが取れていなければ金額ではなく不明にする() {
        let input = MenuBarInput(
            metric: .today, representation: .amount, costSourceMode: .sideBySide,
            gauge: MenuBarGauge(todaySpend: 4, todayBasis: 0, monthSpend: 0, monthBasis: 0),
            cursorUnavailable: true, todayClaude: 4, todayCursor: 0)
        let content = MenuBarReadout.content(for: input)
        #expect(content.title == "Claude \(Money.format(4)) · Cursor \(MenuBarReadout.unavailableText)")
    }

    @Test func Cursorのみで取れていなければ金額全体が不明() {
        let input = MenuBarInput(
            metric: .today, representation: .amount, costSourceMode: .cursorOnly,
            gauge: MenuBarGauge(todaySpend: 0, todayBasis: 0, monthSpend: 0, monthBasis: 0),
            cursorUnavailable: true)
        #expect(MenuBarReadout.content(for: input).title == MenuBarReadout.unavailableText)
    }

    @Test func Cursorのみで取れていなければ割合も不明() {
        // 0% は「使っていない」と同義に見えるので出さない。
        let input = MenuBarInput(
            metric: .today, representation: .percent, costSourceMode: .cursorOnly,
            gauge: MenuBarGauge(todaySpend: 0, todayBasis: 20, monthSpend: 0, monthBasis: 20),
            cursorUnavailable: true)
        #expect(MenuBarReadout.content(for: input).title == MenuBarReadout.unavailableText)
    }

    @Test func 取れていれば従来どおり金額を出す() {
        let input = MenuBarInput(
            metric: .today, representation: .amount, costSourceMode: .sideBySide,
            gauge: MenuBarGauge(todaySpend: 6, todayBasis: 0, monthSpend: 0, monthBasis: 0),
            cursorUnavailable: false, todayClaude: 4, todayCursor: 2)
        #expect(MenuBarReadout.content(for: input).title.contains(Money.format(2)))
    }

    @Test func 合算モードの金額は1つの合計だけ() {
        let input = MenuBarInput(
            metric: .today, representation: .amount, costSourceMode: .combined,
            gauge: MenuBarGauge(todaySpend: 6, todayBasis: 0, monthSpend: 0, monthBasis: 0),
            todayClaude: 4, todayCursor: 2)
        let content = MenuBarReadout.content(for: input)
        #expect(content.title == Money.format(6))
        #expect(!content.title.contains("Claude"))
    }
}
