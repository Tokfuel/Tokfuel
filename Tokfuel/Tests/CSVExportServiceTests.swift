import Foundation
import Testing
@testable import Tokfuel

private func makeReport(
    periodDays: Int = 3,
    totals: RetokReport.Totals = .init(),
    cacheHitRate: Double = 0,
    perModel: [String: RetokReport.ModelUsage] = [:],
    daily: [String: RetokReport.DailyCost] = [:]
) -> RetokReport {
    RetokReport(periodDays: periodDays, filesScanned: 0, totals: totals,
               cacheHitRate: cacheHitRate, perModel: perModel, daily: daily,
               advice: [], topSessions: [])
}

/// retok の daily 集計が cost / output しか持たない制約（Issue #8 のコメント参照）の下での
/// CSV 組み立てを検証する。日別行は実データだけ、prompts・セッション・モデル別は
/// 期間合計セクションで補う設計。
struct CSVExportServiceTests {
    private static let exportDate = DateComponents(
        calendar: Calendar(identifier: .gregorian), year: 2026, month: 8, day: 5
    ).date!

    /// 期間ラベル・書き出し日時は固定し、粒度・通貨まわりだけを差し替えて呼べるようにする。
    private func csv(_ report: RetokReport, appVersion: String = "1.0",
                     currency: DisplayCurrency = .usd, rate: Double = 0,
                     rateDate: String? = nil,
                     granularity: CSVExportService.Granularity = .daily) -> String {
        CSVExportService.csv(report: report, periodLabel: "今月", appVersion: appVersion,
                             currency: currency, rate: rate, rateDate: rateDate,
                             granularity: granularity, exportDate: Self.exportDate)
    }

    @Test func ヘッダーに期間_書き出し日時_アプリバージョンが入る() {
        let csv = csv(makeReport(), appVersion: "9.9.9")

        #expect(csv.contains("# Tokfuel usage export"))
        #expect(csv.contains("# Period: 今月 ("))
        #expect(csv.contains("# App version: 9.9.9"))
        #expect(csv.contains("# Exported: " + ISO8601DateFormatter().string(from: Self.exportDate)))
        #expect(!csv.contains("# Currency:"))
    }

    @Test func カンマ引用符改行を含むフィールドがエスケープされる() {
        #expect(CSVExportService.escapeField("plain") == "plain")
        #expect(CSVExportService.escapeField("a,b") == "\"a,b\"")
        #expect(CSVExportService.escapeField("a\"b") == "\"a\"\"b\"")
        #expect(CSVExportService.escapeField("a\nb") == "\"a\nb\"")
    }

    @Test func 期間の範囲外の日付は行に出ず窓内の欠測日は0で埋まる() {
        let dates = UsageStore.windowDates(days: 3, endingOn: Self.exportDate)
        let outsideDate = UsageStore.windowDates(days: 4, endingOn: Self.exportDate).first!
        let report = makeReport(
            periodDays: 3,
            daily: [
                dates[0]: .init(cost: 5, output: 100),
                outsideDate: .init(cost: 999, output: 1)
            ])
        let csv = csv(report)

        #expect(csv.contains("Date,Cost (USD),Output Tokens"))
        #expect(csv.contains("\(dates[0]),5.0000,100"))
        #expect(csv.contains("\(dates[1]),0.0000,0"))   // 欠測日は 0 埋め
        #expect(csv.contains("\(dates[2]),0.0000,0"))
        #expect(!csv.contains("999.0000"))               // 窓外の日は出ない
    }

    @Test func 月別は日ごとの値をYYYY_MM単位で合算する() {
        let exportDate = DateComponents(
            calendar: Calendar(identifier: .gregorian), year: 2026, month: 8, day: 2
        ).date!
        let report = makeReport(periodDays: 5, daily: [
            "2026-07-29": .init(cost: 1, output: 10),
            "2026-07-30": .init(cost: 2, output: 20),
            "2026-07-31": .init(cost: 3, output: 30),
            "2026-08-01": .init(cost: 4, output: 40),
            "2026-08-02": .init(cost: 5, output: 50)
        ])
        let monthly = CSVExportService.csv(
            report: report, periodLabel: "今月", appVersion: "1.0",
            currency: .usd, rate: 0, rateDate: nil, granularity: .monthly, exportDate: exportDate)

        #expect(monthly.contains("Month,Cost (USD),Output Tokens"))
        #expect(monthly.contains("2026-07,6.0000,60"))    // 07-29〜07-31 の合算
        #expect(monthly.contains("2026-08,9.0000,90"))    // 08-01〜08-02 の合算
        #expect(!monthly.contains("2026-07-29,"))         // 日別の個別日付の行は出ない
    }

    @Test func ファイル名は粒度を含む() {
        #expect(CSVExportService.suggestedFilename(
            windowStart: "2026-07-01", windowEnd: "2026-07-31", granularity: .daily)
            == "Tokfuel_daily_2026-07-01_2026-07-31.csv")
        #expect(CSVExportService.suggestedFilename(
            windowStart: "2026-07-01", windowEnd: "2026-07-31", granularity: .monthly)
            == "Tokfuel_monthly_2026-07-01_2026-07-31.csv")
    }

    @Test func モデル別内訳はコスト降順で出る() {
        let report = makeReport(perModel: [
            "claude-haiku": .init(cost: 1.0, input: 10, output: 20, requests: 3),
            "claude-opus": .init(cost: 40.0, input: 900, output: 1800, requests: 15)
        ])
        let csv = csv(report)

        let opusIndex = csv.range(of: "claude-opus,")!.lowerBound
        let haikuIndex = csv.range(of: "claude-haiku,")!.lowerBound
        #expect(opusIndex < haikuIndex)
    }

    @Test func 期間合計はtotalsと一致する() {
        let totals = RetokReport.Totals(cost: 37.5, input: 0, output: 0, cacheRead: 0,
                                        cacheWrite: 0, prompts: 10, requests: 20)
        let report = makeReport(totals: totals, cacheHitRate: 0.856)
        let csv = csv(report)

        #expect(csv.contains("Period Totals"))
        #expect(csv.contains("37.5000,10,20,85.6%"))
    }

    @Test func JPY列はレートがあるjpy表示のときだけ出る() {
        let report = makeReport(totals: .init(cost: 10))

        let withJPY = csv(report, currency: .jpy, rate: 150, rateDate: "2026-08-04")
        #expect(withJPY.contains("Cost (JPY)"))
        #expect(withJPY.contains("# Currency: USD + JPY"))
        #expect(withJPY.contains("1500"))   // 10 USD * 150

        let noRate = csv(report, currency: .jpy, rate: 0)
        #expect(!noRate.contains("Cost (JPY)"))

        let usd = csv(report, currency: .usd, rate: 150, rateDate: "2026-08-04")
        #expect(!usd.contains("Cost (JPY)"))
    }
}
