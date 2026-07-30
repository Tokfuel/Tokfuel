#if DEBUG
import Foundation
import Testing
@testable import Tokfuel

/// スクリーンショット生成（TF-0015）の引数解釈。README の絵は CI が撮るので、
/// 出力先の取り違えは気づきにくい。
struct ScreenshotArgumentTests {
    @Test func フラグの次の引数を出力先にする() {
        #expect(ScreenshotRenderer.outputPath(
            arguments: ["Tokfuel", "--screenshot", "assets/screenshot.png"])
                == "assets/screenshot.png")
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

/// ui-preview（TF-0034）の引数解釈。`--screenshot` の出力先パースと同じ形。
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

/// 描画そのもの（ウィンドウサーバが必要）はここでは触らず、絵に写る値の整合だけを見る。
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
        // 日付キーの書式が UsageStore とずれると、ヒーローの金額が「–」になる。
        let store = ScreenshotRenderer.fixtureStore()
        #expect(store.todayCost == ScreenshotRenderer.dailyCosts.last)
        #expect(store.today.prompts == 42)
    }

    @Test func 月間予算は警告状態になる() {
        // 警告メーターと「残り」ラベルを絵に入れるための組み合わせ。
        #expect(BudgetMonitor.level(spend: ScreenshotRenderer.budgetSpend,
                                    limit: ScreenshotRenderer.budgetLimit,
                                    warnPercent: 80) == .warning)
    }

    @Test func 日次予算は超過しない() {
        let today = ScreenshotRenderer.dailyCosts.last ?? 0
        #expect(BudgetMonitor.level(spend: today,
                                    limit: ScreenshotRenderer.dailyBudgetLimit,
                                    warnPercent: 80) == .ok)
    }
}
#endif
