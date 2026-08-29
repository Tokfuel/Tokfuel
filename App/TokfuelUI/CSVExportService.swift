import AppKit
import Foundation
import UniformTypeIdentifiers
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

/// すでにデコード済みの `RetokReport` を CSV に書き出す。retok の daily 集計が cost / output
/// しか持たない制約があるため、日別行はある値だけを載せ、無い値は期間合計セクションで補う。
public enum CSVExportService {
    public enum Granularity: String {
        case daily, monthly

        var columnLabel: String { self == .daily ? "Date" : "Month" }
        var periodSuffix: String { self == .daily ? "日別" : "月別" }
    }

    private static let newline = "\n"
    nonisolated(unsafe) private static let isoDateFormatter = ISO8601DateFormatter()
    private static let numberLocale = Locale(identifier: "en_US_POSIX")

    public static func csv(
        report: RetokReport,
        periodLabel: String,
        appVersion: String,
        currency: DisplayCurrency,
        rate: Double,
        rateDate: String?,
        granularity: Granularity,
        exportDate: Date = Date()
    ) -> String {
        let includesJPY = currency == .jpy && rate > 0
        let (dates, from, to) = windowBounds(days: report.periodDays, endingOn: exportDate)

        var lines: [String] = []
        lines.append("# Tokfuel usage export")
        lines.append("# Period: \(periodLabel) (\(from)〜\(to), \(report.periodDays)日, "
                     + "\(granularity.periodSuffix))")
        lines.append("# Exported: \(iso8601(exportDate))")
        lines.append("# App version: \(appVersion)")
        if includesJPY {
            lines.append("# Currency: USD + JPY (reference rate 1 USD = ¥\(formatRate(rate)), "
                         + "as of \(rateDate ?? "-"))")
        }
        lines.append("")

        lines.append(row(mainHeader(granularity: granularity, includesJPY: includesJPY)))
        for bucket in mainRows(dates: dates, daily: report.daily, granularity: granularity) {
            lines.append(row(mainRow(label: bucket.label, cost: bucket.cost, output: bucket.output,
                                     includesJPY: includesJPY, rate: rate)))
        }
        lines.append("")

        lines.append("Period Totals")
        lines.append(row(totalsHeader(includesJPY: includesJPY)))
        lines.append(row(totalsRow(report.totals, cacheHitRate: report.cacheHitRate,
                                   includesJPY: includesJPY, rate: rate)))
        lines.append("")

        lines.append("Model Breakdown")
        lines.append(row(modelHeader(includesJPY: includesJPY)))
        for (model, usage) in report.modelsSorted {
            lines.append(row(modelRow(model: model, usage: usage, includesJPY: includesJPY, rate: rate)))
        }

        return lines.joined(separator: newline) + newline
    }

    /// 続けて書き出しても上書きし合わないようにする。
    public static func suggestedFilename(windowStart: String, windowEnd: String,
                                  granularity: Granularity) -> String {
        "Tokfuel_\(granularity.rawValue)_\(windowStart)_\(windowEnd).csv"
    }

    @MainActor
    public static func presentSavePanel(report: RetokReport, periodLabel: String, granularity: Granularity) {
        let settings = AppSettings.shared
        let currency = settings.displayCurrency
        let rate = Money.currentRate()
        let rateDate = UserDefaults.standard.string(forKey: Money.rateDateKey)
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "dev"

        let content = csv(report: report, periodLabel: periodLabel, appVersion: appVersion,
                          currency: currency, rate: rate, rateDate: rateDate, granularity: granularity)
        let (_, from, to) = windowBounds(days: report.periodDays, endingOn: Date())

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedFilename(windowStart: from, windowEnd: to,
                                                        granularity: granularity)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            // BOM 付き UTF-8: ヘッダーとモデル名以外は日本語（期間ラベルなど）を含むので、
            // Excel などが文字化けしないようにする。
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(content.utf8))
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "CSV の書き出しに失敗しました"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }


    /// 両方が窓を必要とするので、計算をここ 1 箇所にまとめる。
    private static func windowBounds(days: Int, endingOn end: Date) -> (dates: [String], from: String, to: String) {
        let dates = UsageStore.windowDates(days: days, endingOn: end)
        let from = dates.first ?? UsageStore.reportWindowStart(days: days, endingOn: end)
        return (dates, from, dates.last ?? from)
    }

    private static func costHeaderColumns(includesJPY: Bool) -> [String] {
        includesJPY ? ["Cost (USD)", "Cost (JPY)"] : ["Cost (USD)"]
    }

    private static func costColumns(_ usd: Double, includesJPY: Bool, rate: Double) -> [String] {
        includesJPY ? [formatUSD(usd), formatJPY(usd, rate: rate)] : [formatUSD(usd)]
    }

    private static func mainHeader(granularity: Granularity, includesJPY: Bool) -> [String] {
        [granularity.columnLabel] + costHeaderColumns(includesJPY: includesJPY) + ["Output Tokens"]
    }

    private static func mainRow(label: String, cost: Double, output: Int,
                                includesJPY: Bool, rate: Double) -> [String] {
        [label] + costColumns(cost, includesJPY: includesJPY, rate: rate) + [String(output)]
    }

    private struct MainBucket {
        let label: String
        let cost: Double
        let output: Int
    }

    private static func mainRows(dates: [String], daily: [String: RetokReport.DailyCost],
                                 granularity: Granularity) -> [MainBucket] {
        switch granularity {
        case .daily:
            return dates.map { date in
                let day = daily[date]
                return MainBucket(label: date, cost: day?.cost ?? 0, output: day?.output ?? 0)
            }
        case .monthly:
            var order: [String] = []
            var costByMonth: [String: Double] = [:]
            var outputByMonth: [String: Int] = [:]
            for date in dates {
                let month = String(date.prefix(7))   // "YYYY-MM"
                if costByMonth[month] == nil { order.append(month) }
                let day = daily[date]
                costByMonth[month, default: 0] += day?.cost ?? 0
                outputByMonth[month, default: 0] += day?.output ?? 0
            }
            return order.map { month in
                MainBucket(label: month, cost: costByMonth[month] ?? 0, output: outputByMonth[month] ?? 0)
            }
        }
    }

    private static func totalsHeader(includesJPY: Bool) -> [String] {
        costHeaderColumns(includesJPY: includesJPY) + ["Prompts", "API Requests", "Cache Hit Rate"]
    }

    private static func totalsRow(_ totals: RetokReport.Totals, cacheHitRate: Double,
                                  includesJPY: Bool, rate: Double) -> [String] {
        costColumns(totals.cost, includesJPY: includesJPY, rate: rate)
            + [String(totals.prompts), String(totals.requests), formatPercent(cacheHitRate)]
    }

    private static func modelHeader(includesJPY: Bool) -> [String] {
        ["Model"] + costHeaderColumns(includesJPY: includesJPY) + ["Input Tokens", "Output Tokens", "Requests"]
    }

    private static func modelRow(model: String, usage: RetokReport.ModelUsage,
                                 includesJPY: Bool, rate: Double) -> [String] {
        [model] + costColumns(usage.cost, includesJPY: includesJPY, rate: rate)
                + [String(usage.input), String(usage.output), String(usage.requests)]
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escapeField).joined(separator: ",")
    }

    public static func escapeField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"")
              || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }


    private static func formatUSD(_ usd: Double) -> String {
        String(format: "%.4f", locale: numberLocale, usd)
    }

    private static func formatJPY(_ usd: Double, rate: Double) -> String {
        String(Int(Money.displayAmount(forUSD: usd, currency: .jpy, rate: rate)))
    }

    private static func formatPercent(_ fraction: Double) -> String {
        String(format: "%.1f%%", locale: numberLocale, fraction * 100)
    }

    private static func formatRate(_ rate: Double) -> String {
        String(format: "%.2f", locale: numberLocale, rate)
    }

    private static func iso8601(_ date: Date) -> String {
        isoDateFormatter.string(from: date)
    }
}
