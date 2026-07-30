import Foundation
import Testing
@testable import Tokfuel

// TF #53 — 推移チャートの累積化・集計期間の丸め・着地予測・レポートキャッシュ。

/// 積み上げ行 → 累積列の畳み込み。折れ線の形が崩れると予算比較が嘘になる。
struct CumulativeRowsTests {
    private let dates = ["2026-07-01", "2026-07-02", "2026-07-03"]

    private func row(_ date: String, _ source: String, _ cost: Double) -> UsageStore.ChartRow {
        UsageStore.ChartRow(date: date, source: source, cost: cost)
    }

    @Test func 日付順の累積になる() {
        let rows = [row("2026-07-02", "Claude", 2), row("2026-07-01", "Claude", 1),
                    row("2026-07-03", "Claude", 3)]
        let points = UsageStore.cumulativeRows(from: rows, over: dates)
        #expect(points.map(\.date) == dates)
        #expect(points.map(\.total) == [1, 3, 6])
    }

    @Test func 同日の複数ソースは合算する() {
        let rows = [row("2026-07-01", "Claude", 1), row("2026-07-01", "Cursor", 2)]
        let points = UsageStore.cumulativeRows(from: rows, over: dates)
        #expect(points.first?.total == 3)
    }

    @Test func コストの無い日は前日の値を引き継ぐ() {
        // 中日が抜けると線が詰まって傾き（ペース）が歪むので、平らな点として埋まる。
        let rows = [row("2026-07-01", "Claude", 1), row("2026-07-03", "Claude", 3)]
        let points = UsageStore.cumulativeRows(from: rows, over: dates)
        #expect(points.map(\.total) == [1, 1, 4])
    }

    @Test func 窓の外の行は数えない() {
        // reloadBudget が広い予算窓の日別を補完するため、窓の外の日付が行に混ざりうる。
        let rows = [row("2026-06-15", "Cursor", 100), row("2026-07-01", "Claude", 1)]
        let points = UsageStore.cumulativeRows(from: rows, over: dates)
        #expect(points.map(\.total) == [1, 1, 1])
    }

    @Test func 窓の日付列は今日を含む連続した日になる() {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let end = f.date(from: "2026-07-30")!
        #expect(UsageStore.windowDates(days: 3, endingOn: end)
                == ["2026-07-28", "2026-07-29", "2026-07-30"])
    }
}

/// 暦月予算の着地予測（月初からの日次ペース × 月の日数）。
struct MonthEndProjectionTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }()

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    @Test func 月半ばの消費を月末まで線形に伸ばす() {
        // 7/15 までに $150 → 日次 $10 × 31 日 = $310。
        let p = UsageStore.monthEndProjection(spend: 150, now: date("2026-07-15"),
                                              calendar: calendar)
        #expect(p != nil)
        #expect(abs((p ?? 0) - 310) < 0.0001)
    }

    @Test func 月末日は現在の消費ペースがそのまま着地になる() {
        let p = UsageStore.monthEndProjection(spend: 310, now: date("2026-07-31"),
                                              calendar: calendar)
        #expect(abs((p ?? 0) - 310) < 0.0001)
    }

    @Test func 消費ゼロは外挿の根拠が無いので予測しない() {
        #expect(UsageStore.monthEndProjection(spend: 0, now: date("2026-07-15"),
                                              calendar: calendar) == nil)
    }
}

/// 保存済み集計期間の丸め。「今日 (1)」はピッカーから消えたので 7 日へ倒す。
struct SanitizedReportDaysTests {
    @Test func 現行の選択肢はそのまま() {
        #expect(UsageStore.sanitizedReportDays(7) == 7)
        #expect(UsageStore.sanitizedReportDays(30) == 30)
    }

    @Test func かつての今日は近い7日へ倒す() {
        #expect(UsageStore.sanitizedReportDays(1) == 7)
    }

    @Test func 未設定と未知の値は既定の30日() {
        #expect(UsageStore.sanitizedReportDays(0) == 30)
        #expect(UsageStore.sanitizedReportDays(99) == 30)
    }
}

/// 直近レポートのディスクキャッシュ。実ユーザーの Application Support には触れない。
struct ReportCacheTests {
    private func fixture() -> RetokReport {
        RetokReport(
            periodDays: 7, filesScanned: 3,
            totals: RetokReport.Totals(cost: 12.5, input: 100, output: 50,
                                       cacheRead: 10, cacheWrite: 5, prompts: 4, requests: 8),
            cacheHitRate: 0.5,
            perModel: ["claude-sonnet-5": RetokReport.ModelUsage(cost: 12.5, input: 100,
                                                                 output: 50, requests: 8)],
            daily: ["2026-07-29": RetokReport.DailyCost(cost: 12.5, output: 50)],
            advice: [RetokReport.Advice(severity: "info", key: "k", title: "t", detail: "d")],
            topSessions: [RetokReport.TopSession(session: "s", project: "p", cost: 1,
                                                 prompts: 2, maxContext: 3)])
    }

    private let projects = "/Users/someone/.claude"

    @Test func 保存して読み戻せる() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-report-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = ReportCache(directory: dir)

        cache.save(fixture(), days: 7, lang: "ja", projectsPath: projects)
        let loaded = cache.load(days: 7, lang: "ja", projectsPath: projects)
        #expect(loaded?.totals.cost == 12.5)
        #expect(loaded?.daily["2026-07-29"]?.cost == 12.5)
        #expect(loaded?.advice.first?.key == "k")
        #expect(loaded?.topSessions.first?.maxContext == 3)
    }

    @Test func 期間や言語やディレクトリが違うキャッシュは混ざらない() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-report-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = ReportCache(directory: dir)

        cache.save(fixture(), days: 7, lang: "ja", projectsPath: projects)
        #expect(cache.load(days: 30, lang: "ja", projectsPath: projects) == nil)
        #expect(cache.load(days: 7, lang: "en", projectsPath: projects) == nil)
        #expect(cache.load(days: 7, lang: "ja", projectsPath: "/Volumes/work/.claude") == nil)
    }

    @Test func キャッシュが無ければnil() {
        let cache = ReportCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-missing-\(UUID().uuidString)"))
        #expect(cache.load(days: 7, lang: "ja", projectsPath: projects) == nil)
    }
}
