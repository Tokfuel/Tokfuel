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

#if DEBUG

/// README の絵は CI が撮るので、引数解釈が壊れると全自動プレビューが止まる。
struct ScreenshotArgumentTests {
    @Test func フラグの次の引数を出力先にする() {
        #expect(ScreenshotRenderer.outputPath(
            arguments: ["Tokfuel", "--screenshot", "Assets/screenshot.png"])
                == "Assets/screenshot.png")
    }

    @Test func フラグが無ければ通常起動() {
        #expect(ScreenshotRenderer.outputPath(arguments: ["Tokfuel"]) == nil)
    }

    @Test func 出力先が続かない指定は受け付けない() {
        #expect(ScreenshotRenderer.outputPath(arguments: ["Tokfuel", "--screenshot"]) == nil)
        #expect(ScreenshotRenderer.outputPath(
            arguments: ["Tokfuel", "--screenshot", "-AppleAccentColor", "1"]) == nil)
    }
}

/// `--screenshot` と同じ形で `--ui-preview` の出力先を解釈する。
struct UIPreviewArgumentTests {
    @Test func フラグの次の引数を出力先ディレクトリにする() {
        #expect(ScreenshotRenderer.outputDirectory(
            arguments: ["Tokfuel", "--ui-preview", "/tmp/ui-preview"])
                == "/tmp/ui-preview")
    }

    @Test func フラグが無ければ通常起動() {
        #expect(ScreenshotRenderer.outputDirectory(arguments: ["Tokfuel"]) == nil)
    }

    @Test func 出力先が続かない指定は受け付けない() {
        #expect(ScreenshotRenderer.outputDirectory(arguments: ["Tokfuel", "--ui-preview"]) == nil)
        #expect(ScreenshotRenderer.outputDirectory(
            arguments: ["Tokfuel", "--ui-preview", "-AppleAccentColor", "1"]) == nil)
    }
}

/// フィクスチャが崩れると README の絵が「–」や空セクションだらけになるため。
@MainActor
struct ScreenshotFixtureTests {
    @Test func 期間合計は日別コストの合計と一致する() {
        let report = ScreenshotRenderer.fixtureReport()
        let sum = ScreenshotRenderer.dailyCosts.reduce(0, +)
        #expect(abs(report.totals.cost - sum) < 0.0001)
        #expect(report.daily.count == ScreenshotRenderer.reportDays)
    }

    @Test func モデル別の合計も期間合計に一致する() {
        let report = ScreenshotRenderer.fixtureReport()
        let sum = report.perModel.values.reduce(0) { $0 + $1.cost }
        #expect(abs(report.totals.cost - sum) < 0.0001)
    }

    @Test func 今日のコストが引ける() {
        let store = ScreenshotRenderer.fixtureStore()
        #expect(store.todayCost(forSource: CostSourceMode.claudeSourceID)
                == ScreenshotRenderer.dailyCosts.last)
        #expect(store.todayCost(forSource: CostSourceMode.cursorSourceID)
                == ScreenshotRenderer.cursorTodayCost)
        #expect(store.todayCost == (ScreenshotRenderer.dailyCosts.last ?? 0)
                + ScreenshotRenderer.cursorTodayCost)
    }

    @Test func Cursorのモデル別内訳は今日のコストに一致する() {
        let sum = ScreenshotRenderer.cursorModelCosts.values.reduce(0, +)
        #expect(abs(sum - ScreenshotRenderer.cursorTodayCost) < 0.0001)
    }

    @Test func 節約のヒントは両ソースぶんが絵に出る() {
        // popover-advice の絵はここが空だと「節約のヒント」ごと消える。
        #expect(!ScreenshotRenderer.fixtureReport().advice.isEmpty)
        let cursor = CursorAdvice.hints(for: .init(
            modelCosts: ScreenshotRenderer.cursorModelCosts,
            cursorTotal: ScreenshotRenderer.cursorTodayCost,
            claudeTotal: ScreenshotRenderer.dailyCosts.reduce(0, +)))
        #expect(cursor.map(\.key).sorted() == [CursorAdvice.Key.dominantModel,
                                               CursorAdvice.Key.unpricedModels].sorted())
    }

    /// `popover-sessions` の絵は、Claude と Cursor が 1 本のリストに混ざった状態を写す。
    @Test func セッションのフィクスチャはClaudeとCursorが混ざる() {
        let store = ScreenshotRenderer.sessionsFixtureStore()
        #expect(store.driverSessionsByID["cursor"]?.count == 2)

        let settings = AppSettings.shared
        let previous = settings.costSourceMode
        settings.costSourceMode = .sideBySide
        defer { settings.costSourceMode = previous }

        let report = ScreenshotRenderer.fixtureReport(
            topSessions: ScreenshotRenderer.claudeTopSessions, advice: [])
        let rows = store.topSessionRows(for: report)
        #expect(rows.count == UsageStore.topSessionLimit)
        #expect(Set(rows.map(\.source)) == ["Claude", "Cursor"])
        #expect(rows.contains { $0.isEstimated })
    }

    /// README の 1 枚目は折り返しの上だけなので、セッション行を積まない状態のままにする。
    @Test func READMEのフィクスチャはセッションを積まない() {
        #expect(ScreenshotRenderer.fixtureReport().topSessions.isEmpty)
        #expect(ScreenshotRenderer.fixtureStore().driverSessionsByID.isEmpty)
    }

    @Test func 月間予算は警告状態になる() {
        #expect(BudgetMonitor.level(spend: ScreenshotRenderer.budgetSpend,
                                    limit: ScreenshotRenderer.budgetLimit,
                                    warnPercent: 80) == .warning)
    }

    @Test func 予算アラートのフィクスチャは警告状態で文面を持つ() {
        let content = ScreenshotRenderer.budgetAlertContent
        #expect(content.level == .warning)
        #expect(content.spend == ScreenshotRenderer.budgetSpend)
        #expect(content.limit == ScreenshotRenderer.budgetLimit)
        #expect(content.percent == 83)
        #expect(!content.message.title.isEmpty)
    }

    @Test func 日次予算は超過しない() {
        let today = ScreenshotRenderer.dailyCosts.last ?? 0
        #expect(BudgetMonitor.level(spend: today,
                                    limit: ScreenshotRenderer.dailyBudgetLimit,
                                    warnPercent: 80) == .ok)
    }
}
#endif
