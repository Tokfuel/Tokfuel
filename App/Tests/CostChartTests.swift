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

/// 推移チャート X 軸の間引き。今年で週ごとだとラベルが潰れる。
struct ChartXAxisLabelTests {
    private func isoDates(from start: String, count: Int) -> [String] {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar(identifier: .gregorian)
        let origin = f.date(from: start)!
        return (0..<count).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: origin).map(f.string)
        }
    }

    @Test func 今週は全日を出す() {
        let dates = isoDates(from: "2026-07-27", count: 5)
        #expect(PopoverView.xAxisShortDates(
            fromISODates: dates, period: .thisWeek, weekStart: 2)
            == ["07/27", "07/28", "07/29", "07/30", "07/31"])
    }

    @Test func 今月は週始まりだけに間引く() {
        let dates = isoDates(from: "2026-07-01", count: 31)
        let labels = PopoverView.xAxisShortDates(
            fromISODates: dates, period: .thisMonth, weekStart: 2) // Monday
        #expect(labels == ["07/06", "07/13", "07/20", "07/27"])
    }

    @Test func 今年は月初だけ最大6個() {
        let dates = isoDates(from: "2026-01-01", count: 365)
        let labels = PopoverView.xAxisShortDates(
            fromISODates: dates, period: .thisYear, weekStart: 2)
        #expect(labels.count <= 6)
        #expect(labels.first == "01/01")
        #expect(labels.contains("07/01") || labels.contains("06/01") || labels.contains("08/01"))
        // 週ごと（約 52）まで残っていないこと。
        #expect(labels.count < 12)
    }

    @Test func 今年の表示文言は月だけ() {
        #expect(PopoverView.xAxisLabel("01/01", period: .thisYear) == "1月")
        #expect(PopoverView.xAxisLabel("12/01", period: .thisYear) == "12月")
        #expect(PopoverView.xAxisLabel("07/06", period: .thisMonth) == "07/06")
    }
}

/// 旧ローリング日数 → 暦期間への移行と、暦窓の日数計算。
struct ReportPeriodTests {
    private let tokyo: TimeZone = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tokyo
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    @Test func 旧日数からの移行() {
        #expect(ReportPeriod.migrated(fromLegacyDays: 1) == .today)
        #expect(ReportPeriod.migrated(fromLegacyDays: 7) == .thisWeek)
        #expect(ReportPeriod.migrated(fromLegacyDays: 30) == .thisMonth)
        #expect(ReportPeriod.migrated(fromLegacyDays: 365) == .thisYear)
        #expect(ReportPeriod.migrated(fromLegacyDays: 0) == .thisMonth)
        #expect(ReportPeriod.migrated(fromLegacyDays: 99) == .thisMonth)
    }

    @Test func UserDefaultsの新キーを優先する() {
        let suite = "tokfuel-report-period-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(7, forKey: UsageStore.legacyReportDaysKey)
        defaults.set(ReportPeriod.thisYear.rawValue, forKey: UsageStore.reportPeriodKey)
        #expect(UsageStore.resolvedReportPeriod(in: defaults) == .thisYear)
    }

    @Test func 旧キーだけのときは移行する() {
        let suite = "tokfuel-report-period-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(7, forKey: UsageStore.legacyReportDaysKey)
        #expect(UsageStore.resolvedReportPeriod(in: defaults) == .thisWeek)
    }

    @Test func 今月は1日から今日までの日数() {
        let w = UsageStore.reportWindow(
            period: .thisMonth, weekStart: .monday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-07-01")
        #expect(w.days == 31)
    }

    @Test func 今週は月曜始まりで数える() {
        // 2026-07-31 は金曜。月曜始まりなら 7/27〜7/31 の 5 日。
        let w = UsageStore.reportWindow(
            period: .thisWeek, weekStart: .monday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-07-27")
        #expect(w.days == 5)
    }

    @Test func 今週は日曜始まりにも切り替えられる() {
        // 同じ金曜でも日曜始まりなら 7/26〜7/31 の 6 日。
        let w = UsageStore.reportWindow(
            period: .thisWeek, weekStart: .sunday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-07-26")
        #expect(w.days == 6)
    }

    @Test func 今週は土曜始まりにも切り替えられる() {
        let w = UsageStore.reportWindow(
            period: .thisWeek, weekStart: .saturday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-07-25")
        #expect(w.days == 7)
    }

    @Test func 今年は1月1日から() {
        let w = UsageStore.reportWindow(
            period: .thisYear, weekStart: .monday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-01-01")
        #expect(w.days == 212)
    }

    @Test func 今日は1日() {
        let w = UsageStore.reportWindow(
            period: .today, weekStart: .monday,
            endingOn: date("2026-07-31"), timeZone: tokyo)
        #expect(w.start == "2026-07-31")
        #expect(w.days == 1)
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

        cache.save(fixture(), period: .thisWeek, weekStart: .monday, days: 7,
                   lang: "ja", projectsPath: projects)
        let loaded = cache.load(period: .thisWeek, weekStart: .monday, days: 7,
                                lang: "ja", projectsPath: projects)
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

        cache.save(fixture(), period: .thisWeek, weekStart: .monday, days: 7,
                   lang: "ja", projectsPath: projects)
        #expect(cache.load(period: .thisMonth, weekStart: .monday, days: 7,
                           lang: "ja", projectsPath: projects) == nil)
        #expect(cache.load(period: .thisWeek, weekStart: .sunday, days: 7,
                           lang: "ja", projectsPath: projects) == nil)
        #expect(cache.load(period: .thisWeek, weekStart: .monday, days: 7,
                           lang: "en", projectsPath: projects) == nil)
        #expect(cache.load(period: .thisWeek, weekStart: .monday, days: 7,
                           lang: "ja", projectsPath: "/Volumes/work/.claude") == nil)
    }

    @Test func キャッシュが無ければnil() {
        let cache = ReportCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-missing-\(UUID().uuidString)"))
        #expect(cache.load(period: .thisWeek, weekStart: .monday, days: 7,
                           lang: "ja", projectsPath: projects) == nil)
    }
}
