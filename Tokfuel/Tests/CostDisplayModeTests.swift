import Foundation
import Testing
@testable import Tokfuel

@Suite struct CostDisplayModeTests {
    @Test func displayedSpendはモードごとに合成する() {
        #expect(UsageStore.displayedSpend(claude: 4, cursor: 2, mode: .combined) == 6)
        #expect(UsageStore.displayedSpend(claude: 4, cursor: 2, mode: .sideBySide) == 6)
        #expect(UsageStore.displayedSpend(claude: 4, cursor: 2, mode: .claudeOnly) == 4)
        #expect(UsageStore.displayedSpend(claude: 4, cursor: 2, mode: .cursorOnly) == 2)
    }

    @Test func includesフラグは並べてでも両方true() {
        #expect(CostSourceMode.sideBySide.includesClaude)
        #expect(CostSourceMode.sideBySide.includesCursor)
        #expect(!CostSourceMode.claudeOnly.includesCursor)
        #expect(!CostSourceMode.cursorOnly.includesClaude)
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
