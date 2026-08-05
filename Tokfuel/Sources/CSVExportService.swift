import AppKit
import Foundation
import UniformTypeIdentifiers

/// `RetokReport` を CSV に書き出す（TF-0008）。新しい分析はせず、すでにデコード済みの
/// フィールドをテーブルへ写すだけ。書き出しはユーザーが明示的に ⋯ メニューから操作した
/// ときだけ起き、Mac の外へは送らない（保存先を選ぶのもユーザー自身）。
///
/// retok 自身の `daily` 集計（`Resources/retok.py`）は日ごとに cost と output トークンしか
/// 持たず、prompts・セッション数・モデル別の内訳は期間合計にしか無い。retok は無改変で
/// 同梱する制約があるため、日別行はある値だけを載せ、無い値は期間合計セクションで補う。
enum CSVExportService {
    /// メインテーブルの行の粒度。日別はそのまま retok の `daily` を 1 行 1 日で出し、
    /// 月別は同じ値を `YYYY-MM` 単位で合算する（新しい分析ではなく合算だけ）。
    enum Granularity: String {
        case daily, monthly

        var columnLabel: String { self == .daily ? "Date" : "Month" }
        var periodSuffix: String { self == .daily ? "日別" : "月別" }
    }

    private static let newline = "\n"
    // ISO8601DateFormatter はスレッド安全（Apple ドキュメント）だが Sendable ではない
    // （UsageEventLog.swift・CursorCostDriver.swift と同じ理由でキャッシュする）。
    nonisolated(unsafe) private static let isoDateFormatter = ISO8601DateFormatter()
    // String(format:) の %f はユーザーのロケールに従って小数点をカンマにすることがある
    // （例: フランス語・ドイツ語）。CSV の数値列がロケール依存で崩れないよう固定する。
    private static let numberLocale = Locale(identifier: "en_US_POSIX")

    /// CSV 本文を組み立てる。
    static func csv(
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

    /// 書き出し先のデフォルトファイル名。粒度と窓の開始〜終了日を含め、日別・月別を
    /// 続けて書き出しても上書きし合わないようにする。
    static func suggestedFilename(windowStart: String, windowEnd: String,
                                  granularity: Granularity) -> String {
        "Tokfuel_\(granularity.rawValue)_\(windowStart)_\(windowEnd).csv"
    }

    /// ⋯ メニューの「CSV を書き出す（日別 / 月別）」から呼ぶ。NSSavePanel は
    /// `SettingsView.choose()` の `NSOpenPanel` と同じ、その場で `runModal()` するだけの
    /// 素朴な流儀に合わせる。
    @MainActor
    static func presentSavePanel(report: RetokReport, periodLabel: String, granularity: Granularity) {
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
            // BOM 無しだと Excel が文字化けさせることがある。
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

    // MARK: - 行の組み立て

    /// 表示窓の開始・終了日と、日別ループに使う日付列。csv() と presentSavePanel() の
    /// 両方が窓を必要とするので、計算をここ 1 箇所にまとめる。
    private static func windowBounds(days: Int, endingOn end: Date) -> (dates: [String], from: String, to: String) {
        let dates = UsageStore.windowDates(days: days, endingOn: end)
        let from = dates.first ?? UsageStore.reportWindowStart(days: days, endingOn: end)
        return (dates, from, dates.last ?? from)
    }

    /// USD 列（と、必要なら直後に JPY 列）。ヘッダーと行の両方がこの形を共有する。
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

    /// 日別はそのまま 1 日 1 行。月別は同じ `dates` を `YYYY-MM` で束ね、その月に含まれる
    /// 窓内の日ぶんだけ cost/output を合算する（窓外・欠測日は日別と同じく 0 扱い）。
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

    /// RFC4180 相当のエスケープ: カンマ・引用符・改行を含むフィールドだけを引用符で囲む。
    static func escapeField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"")
              || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - フォーマット

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
