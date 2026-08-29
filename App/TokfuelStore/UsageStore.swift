import Foundation
import Combine
import TokfuelCore
import TokfuelSettings
import TokfuelClaude
import TokfuelCursor
import TokfuelCodex
import TokfuelBudget

@MainActor
public final class UsageStore: ObservableObject {
    @Published public var daily: [DailyUsage] = []
    @Published public var lastUpdated: Date?
    @Published public var isLoading = false

    @Published private var loadedReport: RetokReport?

    public var report: RetokReport? {
        get {
            #if DEBUG
            return DebugSettings.shared.simulatesMissingReport ? nil : loadedReport
            #else
            return loadedReport
            #endif
        }
        set { loadedReport = newValue }
    }
    @Published public var retokError: String?
    @Published public var isReportLoading = false
    /// 連打時に古い結果が新しい結果を上書きしないようにする世代カウンタ。
    private var reportGeneration = 0
    private var budgetGeneration = 0
    private var reportTask: Task<Void, Never>?
    /// 追従モードの軽い更新（reloadToday）。重い集計とは別に持ち、互いに打ち消し合わせない。
    private var todayTask: Task<Void, Never>?
    private var budgetTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    @Published public var reportPeriod: ReportPeriod {
        didSet {
            if oldValue != reportPeriod {
                defaults.set(reportPeriod.rawValue, forKey: Keys.reportPeriod)
                reloadReport()
            }
        }
    }
    /// 推移チャートの描画形式（日別バー / 累積折れ線）。純粋な表示切替なので再解析はしない。
    @Published public var costChartStyle: CostChartStyle {
        didSet {
            if oldValue != costChartStyle {
                defaults.set(costChartStyle.rawValue, forKey: Keys.costChartStyle)
            }
        }
    }
    private let settings: AppSettings
    private let defaults: UserDefaults
    private let costDrivers: [any CostDriver]

    /// private にしていないのは、表示モデルのテストから直接注入できるようにするため。
    /// （extension は保持型プロパティを持てないので、この 2 つだけ本体に残る）。
    @Published public var driverDailyByID: [String: [String: Double]] = [:]

    @Published public var driverModelByID: [String: [String: Double]] = [:]

    @Published public var driverHealthByID: [String: CostSnapshot.Health] = [:]

    /// 「劣化しているなら開くたび取り直す」にはしない——retok の再実行を伴うので、
    /// ユーザーが実際にサインインしに行った回だけに限る。
    @Published public var awaitingSignInRecheck = false

    @Published public var driverSessionsByID: [String: [CostSnapshot.Session]] = [:]

    public nonisolated static let costChartStyleKey = "costChartStyle"
    public nonisolated static let reportPeriodKey = "reportPeriod"
    /// 旧ローリング日数。新キー未設定時の移行読み取り専用。もう書かない。
    public nonisolated static let legacyReportDaysKey = "reportDays"

    private enum Keys {
        static let reportPeriod = UsageStore.reportPeriodKey
        static let legacyReportDays = UsageStore.legacyReportDaysKey
        static let costChartStyle = UsageStore.costChartStyleKey
    }

    public init(
        settings: AppSettings = .shared,
        defaults: UserDefaults = .standard,
        costDrivers: [any CostDriver] = []
    ) {
        self.settings = settings
        self.defaults = defaults
        self.costDrivers = costDrivers
        reportPeriod = Self.resolvedReportPeriod(in: defaults)
        costChartStyle = CostChartStyle(
            rawValue: defaults.string(forKey: Keys.costChartStyle) ?? "") ?? .daily
    }

    public nonisolated static func resolvedReportPeriod(in defaults: UserDefaults) -> ReportPeriod {
        if let raw = defaults.string(forKey: reportPeriodKey),
           let period = ReportPeriod(rawValue: raw) {
            return period
        }
        if defaults.object(forKey: legacyReportDaysKey) != nil {
            return ReportPeriod.migrated(
                fromLegacyDays: defaults.integer(forKey: legacyReportDaysKey))
        }
        return .thisMonth
    }

    @Published private var reportedBudgetSpendBySource: [String: Double] = [:]

    /// DEBUG では読み取りだけデバッグ上書きを通す。書き込みは常に実データ側へ入るので、
    public var budgetSpend: Double {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            if let override = DebugSettings.shared.month { return override }
            #endif
            return Self.displayedSpend(
                bySource: reportedBudgetSpendBySource,
                mode: settings.costSourceMode)
        }
        set {
            setBudgetSpend(bySource: [CostSourceMode.claudeSourceID: newValue])
        }
    }

    public func budgetSpend(forSource id: String) -> Double { reportedBudgetSpendBySource[id] ?? 0 }

    public var claudeBudgetSpend: Double { budgetSpend(forSource: CostSourceMode.claudeSourceID) }

    public var secondaryBudgetSpend: Double {
        reportedBudgetSpendBySource
            .filter { $0.key != CostSourceMode.claudeSourceID }
            .values.reduce(0, +)
    }

    public func setBudgetSpend(bySource: [String: Double]) {
        if reportedBudgetSpendBySource != bySource { reportedBudgetSpendBySource = bySource }
    }

    @Published private var reportedDailyAverage: Double = 0

    public var dailyAverage30: Double {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            return DebugSettings.shared.average ?? reportedDailyAverage
            #else
            return reportedDailyAverage
            #endif
        }
        set { if reportedDailyAverage != newValue { reportedDailyAverage = newValue } }
    }

    @Published private var reportedActiveDays = 0

    public var activeDaysInPeriod: Int {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            #endif
            return reportedActiveDays
        }
        set { if reportedActiveDays != newValue { reportedActiveDays = newValue } }
    }

    public static func dailyAverage(in daily: [String: RetokReport.DailyCost],
                             since start: String, before today: String) -> Double {
        let window = daily.filter { $0.key >= start && $0.key < today && $0.value.cost > 0 }
        guard !window.isEmpty else { return 0 }
        return window.values.reduce(0) { $0 + $1.cost } / Double(window.count)
    }

    public static func activeDays(in daily: [String: RetokReport.DailyCost], since start: String) -> Int {
        daily.filter { $0.key >= start && $0.value.cost > 0 }.count
    }

    public func menuBarInput(isFollowing: Bool = false) -> MenuBarInput {
        // レートの UserDefaults 読み取りを含む変換なので、明滅ループ（最大 12Hz）で
        let dailyLimitUSD = settings.dailyBudgetLimitUSD
        let monthlyLimitUSD = settings.budgetLimitUSD
        return MenuBarInput(
            metric: settings.menuBarMetric,
            representation: settings.menuBarRepresentation,
            basis: settings.menuBarPercentBasis,
            shape: settings.menuBarGaugeShape,
            showsRemaining: settings.menuBarShowsRemaining,
            showsIcon: settings.menuBarShowsIcon,
            costSourceMode: settings.costSourceMode,
            prompts: today.prompts,
            gauge: MenuBarReadout.gauge(
                basis: settings.menuBarPercentBasis,
                todaySpend: todayCost, monthSpend: budgetSpend,
                dailyLimit: dailyLimitUSD, monthlyLimit: monthlyLimitUSD,
                dailyAverage: dailyAverage30, activeDays: activeDaysInPeriod),
            dailyLimit: dailyLimitUSD,
            monthlyLimit: monthlyLimitUSD,
            cursorUnavailable: !degradedSourceWarnings.isEmpty,
            // 並べて表示は Claude と二次ソース合計の 2 列（この Issue では拡張しない）。
            todayClaude: todayCost(forSource: CostSourceMode.claudeSourceID),
            todayCursor: secondaryTodayCost,
            monthClaude: claudeBudgetSpend,
            monthCursor: secondaryBudgetSpend,
            todayLevel: dailyBudgetLevel,
            monthLevel: budgetLevel,
            isFollowing: isFollowing)
    }

    /// ソース別の今日の金額（USD）。追従モード（TF-0080）の `RefreshScheduler` が
    /// 表示モード（`costSourceMode`）で合成する前の生の値を返す — 表示から外している
    /// ソースが動いたときも、追従モードには入る。取得が劣化しているソース（TF-0073 の
    /// `CostSnapshot.Health.degraded`）はキーごと落とす。劣化中の 0 は「使っていない」では
    /// なく「取れなかった」なので、復旧した瞬間の 0 → 実額を増加と読むと誤発火する。
    public var todayCostBySource: [String: Double] {
        let today = Self.dateString(Date())
        var byID = [CostSourceMode.claudeSourceID: report?.cost(on: today) ?? 0]
        for (id, byDate) in driverDailyByID {
            if case .degraded = driverHealthByID[id] { continue }
            byID[id] = byDate[today] ?? 0
        }
        return byID
    }

    public var budgetLevel: BudgetLevel? {
        guard settings.budgetLimit > 0 else { return nil }
        return BudgetMonitor.level(spend: budgetSpend, limit: settings.budgetLimitUSD,
                                   warnPercent: settings.budgetWarnPercent)
    }

    public var dailyBudgetLevel: BudgetLevel? {
        guard settings.dailyBudgetLimit > 0 else { return nil }
        return BudgetMonitor.level(spend: todayCost, limit: settings.dailyBudgetLimitUSD,
                                   warnPercent: settings.budgetWarnPercent)
    }

    public var combinedBudgetLevel: BudgetLevel? {
        switch (budgetLevel, dailyBudgetLevel) {
        case let (m?, d?): return max(m, d)
        case let (m?, nil): return m
        case let (nil, d?): return d
        case (nil, nil): return nil
        }
    }

    public func reload() {
        guard !isLoading else { return }
        isLoading = true
        reloadReport()
        reloadBudget()
        // 間に合わなくてもよい — 取れれば次回以降の CursorPricing.cost() から新しい表を使う。
        Task { await CursorPricingService.refreshIfNeeded() }
        rescanTranscripts()
    }

    /// 追従モード（TF-0080）の軽い更新。今日を含む短い窓だけを取り直し、32 日集計
    /// python3 のサブプロセスを走らせるので、走査日数は 1 日に絞る。
    public func reloadToday() {
        let lang = settings.language.resolved
        let claudeDir = settings.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        let today = Self.dateString(Date())
        let generation = reportGeneration
        todayTask?.cancel()
        todayTask = Task {
            async let retokTask = RetokService.run(
                days: 1, lang: lang, projectsDir: projectsOverride, provider: "claude"
            )
            async let driverTask = self.fetchDriverSnapshots(from: today, to: today)

            let short = try? await retokTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // 表示中のレポートがまだ無いうちは何もしない。1 日ぶんのレポートで埋めると、
            // 期間合計もモデル別も今日だけの値になって誤解を招く（長期集計が届けば埋まる）。
            if let short, let current = self.report {
                self.report = current.merging(daily: short.daily)
            }
            let snapshots = await driverTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // その場で劣化（TF-0073）へ倒して「—」と注意書きを出す。
            for (id, snapshot) in snapshots {
                var merged = self.driverDailyByID[id] ?? [:]
                for (date, cost) in snapshot.daily { merged[date] = cost }
                self.driverDailyByID[id] = merged
                self.driverHealthByID[id] = snapshot.health
            }
        }
        rescanTranscripts()
    }

    private func rescanTranscripts() {
        let projectsDir = settings.claudeDirectoryURL.appendingPathComponent("projects")
        transcriptTask?.cancel()
        transcriptTask = Task.detached(priority: .userInitiated) {
            let daily = TranscriptScanner.scan(projectsDir: projectsDir)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.daily = daily
                self.lastUpdated = Date()
                if self.isLoading { self.isLoading = false }
            }
        }
    }

    public func reloadReport() {
        let period = reportPeriod
        let weekStart = settings.weekStart
        let window = Self.reportWindow(period: period, weekStart: weekStart)
        let days = window.days
        let lang = settings.language.resolved
        let claudeDir = settings.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        reportGeneration += 1
        let generation = reportGeneration
        reportTask?.cancel()
        isReportLoading = true
        let cacheKeyPath = claudeDir.standardizedFileURL.path
        if let cached = ReportCache.shared.load(
            period: period, weekStart: weekStart, days: days,
            lang: lang, projectsPath: cacheKeyPath
        ) {
            report = cached
        }
        let from = window.start
        let to = Self.dateString(Date())
        reportTask = Task {
            async let retokTask = RetokService.run(
                days: days, lang: lang, projectsDir: projectsOverride, provider: "claude"
            )
            async let driverTask = self.fetchDriverSnapshots(from: from, to: to)
            async let sessionTask = self.fetchDriverSessions(from: from, to: to)

            do {
                let r = try await retokTask
                guard !Task.isCancelled, generation == self.reportGeneration else { return }
                self.report = r
                ReportCache.shared.save(
                    r, period: period, weekStart: weekStart, days: days,
                    lang: lang, projectsPath: cacheKeyPath)
                self.retokError = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == self.reportGeneration else { return }
                self.retokError = error.localizedDescription
            }
            self.isReportLoading = false

            let snapshots = await driverTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // 残る状態を作らないため、空の内訳も含めて毎回置き換える。
            self.applyDriverSnapshots(snapshots)

            let sessions = await sessionTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            self.applyDriverSessions(sessions)
        }
    }

    public func reloadBudget() {
        // 集計が不要になった場合も含めて先に世代を進める。そうしないと、実行中の集計が
        budgetGeneration += 1
        let generation = budgetGeneration
        budgetTask?.cancel()
        guard settings.budgetLimit > 0
                || settings.menuBarMetric.showsMonthlyCost
                || settings.menuBarNeedsDailyAverage else {
            budgetSpend = 0
            dailyAverage30 = 0
            activeDaysInPeriod = 0
            return
        }
        let period = settings.effectiveBudgetPeriod
        let claudeDir = settings.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        let start = BudgetMonitor.periodStart(for: period)
        let today = Self.dateString(Date())
        budgetTask = Task {
            async let retokTask = RetokService.run(
                days: 32, lang: "en", projectsDir: projectsOverride, provider: "claude"
            )
            async let driverTask = self.fetchDriverSnapshots(from: start, to: today)

            // retok が失敗しても（python3 なし等）二次ソースの結果は捨てない — reloadReport() と
            let r = try? await retokTask
            // 設定を連続で変えると 32 日集計が並走しうる。古い結果で新しい結果を上書きしない。
            guard !Task.isCancelled, generation == self.budgetGeneration else { return }

            let claudeSpend = r?.daily
                .filter { $0.key >= start }
                .values.reduce(0) { $0 + $1.cost } ?? 0
            let driverSnapshots = await driverTask
            var spendBySource = [CostSourceMode.claudeSourceID: claudeSpend]
            for (id, snapshot) in driverSnapshots {
                spendBySource[id] = snapshot.daily.values.reduce(0, +)
            }
            self.setBudgetSpend(bySource: spendBySource)
            // reloadReport より予算窓の方が広いことがあるので、日別も予算側の結果で補完する。
            for (id, snapshot) in driverSnapshots {
                var merged = self.driverDailyByID[id] ?? [:]
                for (date, cost) in snapshot.daily { merged[date] = cost }
                self.driverDailyByID[id] = merged
                self.driverHealthByID[id] = snapshot.health
            }

            // 稼働日数・日次平均は retok 専用の指標。budgetSpend と違い二次ソースの分が無いので、
            guard let r else { return }
            self.activeDaysInPeriod = Self.activeDays(in: r.daily, since: start)
            let now = Date()
            // 平均は今日を含めないので、periodStart（今日を含む 30 日 = −29 日）とは 1 日ずれる。
            let averageStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            self.dailyAverage30 = Self.dailyAverage(in: r.daily,
                                                    since: Self.dateString(averageStart),
                                                    before: Self.dateString(now))
        }
    }


    public nonisolated static func dateString(_ date: Date) -> String {
        LocalDay.string(from: date)
    }

    public nonisolated static func reportWindowStart(days: Int, endingOn end: Date = Date()) -> String {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        return dateString(start)
    }

    public struct ReportWindow: Equatable, Sendable {
        let start: String
        let days: Int
    }

    public nonisolated static func reportWindow(
        period: ReportPeriod,
        weekStart: WeekStart,
        endingOn end: Date = Date(),
        timeZone: TimeZone = .current
    ) -> ReportWindow {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = weekStart.weekday
        let endDay = cal.startOfDay(for: end)
        let startDay: Date
        switch period {
        case .today:
            startDay = endDay
        case .thisWeek:
            startDay = cal.dateInterval(of: .weekOfYear, for: endDay)?.start ?? endDay
        case .thisMonth:
            startDay = cal.dateInterval(of: .month, for: endDay)?.start ?? endDay
        case .thisYear:
            startDay = cal.dateInterval(of: .year, for: endDay)?.start ?? endDay
        }
        let days = max(1, (cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        return ReportWindow(start: LocalDay.string(from: startDay, calendar: cal), days: days)
    }

    public var today: DailyUsage {
        let key = Self.dateString(Date())
        return daily.first { $0.date == key } ?? DailyUsage(date: key)
    }

    public func todayCost(forSource id: String) -> Double { todayCostBySource[id] ?? 0 }

    public var secondaryTodayCost: Double {
        driverDaily[Self.dateString(Date())] ?? 0
    }

    public var todayCost: Double {
        #if DEBUG
        if let override = DebugSettings.shared.today { return override }
        #endif
        return Self.displayedSpend(bySource: todayCostBySource, mode: settings.costSourceMode)
    }

    public nonisolated static func displayedSpend(
        bySource: [String: Double], mode: CostSourceMode
    ) -> Double {
        bySource.reduce(0) { $0 + (mode.includes(sourceID: $1.key) ? $1.value : 0) }
    }

}


extension UsageStore {
    /// internalなのは、フォールバック時に古いモデル別を残さないことをテストするため。
    public func applyDriverSnapshots(_ snapshots: [String: CostSnapshot]) {
        driverDailyByID = snapshots.mapValues(\.daily)
        driverModelByID = snapshots.mapValues(\.byModel)
        driverHealthByID = snapshots.mapValues(\.health)
    }

    public func applyDriverSessions(_ sessions: [String: [CostSnapshot.Session]]) {
        driverSessionsByID = sessions
    }

    /// 劣化した二次ソース 1 件ぶんの注意書き。金額の 0 を「使っていない」と誤読させないため、
    public struct SourceWarning: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let message: String
        public let signInBundleID: String?

        public init(id: String, name: String, message: String, signInBundleID: String?) {
            self.id = id
            self.name = name
            self.message = message
            self.signInBundleID = signInBundleID
        }
    }

    /// 劣化警告と「金額が取れていない」の判定は、この集合だけを見る。
    public var displayedDrivers: [any CostDriver] {
        let mode = settings.costSourceMode
        return costDrivers.filter { mode.includes(sourceID: $0.id) }
    }

    private func isDegraded(_ id: String) -> Bool {
        if case .degraded = driverHealthByID[id] { return true }
        return false
    }

    /// 表示対象の二次ソースが全滅していると、ヒーローの 0 円は情報ではなく誤情報なので、
    /// 金額の代わりに「—」を出すために使う。Claude を含むモードでは扱わない
    /// ——retok の失敗はフッターのエラー行が伝えるため。
    public var todayCostUnavailable: Bool {
        guard !settings.costSourceMode.includes(sourceID: CostSourceMode.claudeSourceID)
        else { return false }
        let displayed = displayedDrivers
        guard !displayed.isEmpty else { return false }
        return displayed.allSatisfy { isDegraded($0.id) }
    }

    /// 金額が取れなかった二次ソースの表示名。0 円として並べる代わりに「—」で出すために使う。
    public var unknownSourceNames: [String] {
        degradedSourceWarnings.map(\.name)
    }

    /// 取得が劣化している二次ソースの注意書き。表示対象に入っているドライバのぶんだけ出す
    /// ——合計に含めていないソース（「Claude のみ」での Cursor など）の注意書きは、
    public var degradedSourceWarnings: [SourceWarning] {
        displayedDrivers.compactMap { driver in
            guard case .degraded(let reason) = driverHealthByID[driver.id] else { return nil }
            return SourceWarning(
                id: driver.id,
                name: driver.displayName,
                message: reason.message,
                signInBundleID: reason.isRecoverableBySignIn ? driver.signInBundleID : nil)
        }
    }

    /// インスタンスプロパティなので、これも static ではなくインスタンス側に置く。
    public var secondarySourceNames: [String: String] {
        Dictionary(uniqueKeysWithValues: costDrivers.map { ($0.id, $0.displayName) })
    }

    private func driverCost(id: String, on date: String) -> Double {
        driverDailyByID[id]?[date] ?? 0
    }

    public var driverDaily: [String: Double] {
        var merged: [String: Double] = [:]
        for byDate in driverDailyByID.values {
            for (date, cost) in byDate { merged[date, default: 0] += cost }
        }
        return merged
    }

    /// ソースは出さない（ヒーローの内訳キャプションは $0 も明示するため合算値を直接使う）。
    public var driverBreakdown: [(name: String, cost: Double)] {
        let today = Self.dateString(Date())
        return costDrivers.compactMap { driver in
            let cost = driverCost(id: driver.id, on: today)
            return cost > 0 ? (driver.displayName, cost) : nil
        }
    }

    private func fetchDriverSnapshots(from: String, to: String) async -> [String: CostSnapshot] {
        var byID: [String: CostSnapshot] = [:]
        for driver in costDrivers where driver.isAvailable {
            byID[driver.id] = await driver.snapshot(from: from, to: to)
        }
        return byID
    }

    private func fetchDriverSessions(
        from: String, to: String
    ) async -> [String: [CostSnapshot.Session]] {
        var byID: [String: [CostSnapshot.Session]] = [:]
        for driver in costDrivers where driver.isAvailable {
            let sessions = await driver.sessions(from: from, to: to)
            if !sessions.isEmpty { byID[driver.id] = sessions }
        }
        return byID
    }


    public struct ChartRow: Identifiable {
        public let date: String
        public let source: String
        public let cost: Double
        public var id: String { date + source }

        public init(date: String, source: String, cost: Double) {
            self.date = date
            self.source = source
            self.cost = cost
        }
    }

    public static let claudeSourceLabel = "Claude"

    /// コストが 0 の行は積まない（積み上げバーに幅 0 の区切りが入るのを避ける）。
    public func chartRows(for report: RetokReport) -> [ChartRow] {
        let mode = settings.costSourceMode
        var claudeByDate: [String: Double] = [:]
        for day in report.dailySorted { claudeByDate[day.date] = day.cost }
        let from = Self.reportWindowStart(days: report.periodDays)
        let showsClaude = mode.includes(sourceID: CostSourceMode.claudeSourceID)
        var dates = Set<String>()
        if showsClaude {
            dates.formUnion(claudeByDate.keys.filter { $0 >= from })
        }
        for (id, byDate) in driverDailyByID where mode.includes(sourceID: id) {
            dates.formUnion(byDate.keys.filter { $0 >= from })
        }
        let driverNames = secondarySourceNames
        return dates.sorted().flatMap { date -> [ChartRow] in
            var rows: [ChartRow] = []
            if showsClaude, let claude = claudeByDate[date], claude > 0 {
                rows.append(ChartRow(date: date, source: Self.claudeSourceLabel, cost: claude))
            }
            for (id, byDate) in driverDailyByID where mode.includes(sourceID: id) {
                guard date >= from, let cost = byDate[date], cost > 0 else { continue }
                rows.append(ChartRow(date: date, source: driverNames[id] ?? id, cost: cost))
            }
            return rows
        }
    }

    public struct CumulativePoint: Identifiable {
        public let date: String
        public let total: Double
        public var id: String { date }

        public init(date: String, total: Double) {
            self.date = date
            self.total = total
        }
    }

    /// 表示窓の全日付（古い順）。累積線の X 軸はカテゴリなので、コストの無い日を落とすと
    public nonisolated static func windowDates(days: Int, endingOn end: Date = Date()) -> [String] {
        let cal = Calendar.current
        return (0..<days).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: end).map(dateString)
        }
    }

    public nonisolated static func cumulativeRows(from rows: [ChartRow],
                                           over dates: [String]) -> [CumulativePoint] {
        var byDate: [String: Double] = [:]
        for row in rows { byDate[row.date, default: 0] += row.cost }
        var running = 0.0
        return dates.map { date in
            running += byDate[date] ?? 0
            return CumulativePoint(date: date, total: running)
        }
    }

    public nonisolated static func monthEndProjection(
        spend: Double, now: Date = Date(), calendar: Calendar = .current
    ) -> Double? {
        guard spend > 0,
              let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count
        else { return nil }
        return spend / Double(calendar.component(.day, from: now)) * Double(daysInMonth)
    }

    public enum BudgetChartAnnotation {
        /// 予算窓と表示窓が一致している — 上限の参照線が引ける。
        case referenceLine(limit: Double)
        /// 暦月予算 — 窓はローリング表示と一致しないが、月末着地の予測なら窓に依存しない。
        case monthEndProjection(amount: Double)
    }

    public var cumulativeBudgetAnnotation: BudgetChartAnnotation? {
        guard settings.budgetLimit > 0 else { return nil }
        switch settings.budgetPeriod {
        case .rolling30:
            // チャート側にローリング 30 日窓は無いので、上限の参照線は出さない。
            return nil
        case .calendarMonth:
            // 予算窓と表示窓が初めて一致する組 — 上限の参照線を引ける。
            if reportPeriod == .thisMonth {
                return .referenceLine(limit: settings.budgetLimitUSD)
            }
            return Self.monthEndProjection(spend: budgetSpend)
                .map { .monthEndProjection(amount: $0) }
        }
    }


    public struct ModelCostRow: Identifiable {
        public let source: String?
        public let model: String
        public let cost: Double
        public var id: String { "\(source ?? "all")|\(model)" }

        public init(source: String?, model: String, cost: Double) {
            self.source = source
            self.model = model
            self.cost = cost
        }
    }

    public var cursorModelCosts: [(model: String, cost: Double)] {
        (driverModelByID["cursor"] ?? [:])
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    public func periodTotalCost(for report: RetokReport) -> Double {
        let from = Self.reportWindowStart(days: report.periodDays)
        var bySource = [
            CostSourceMode.claudeSourceID: report.daily
                .filter { $0.key >= from }
                .values.reduce(0) { $0 + $1.cost }
        ]
        for (id, byDate) in driverDailyByID {
            bySource[id] = byDate.filter { $0.key >= from }.values.reduce(0, +)
        }
        return Self.displayedSpend(bySource: bySource, mode: settings.costSourceMode)
    }

    public func modelCostRows(for report: RetokReport) -> [ModelCostRow] {
        let mode = settings.costSourceMode
        let breakdown = settings.costModelBreakdownMode
        let claude: [(String, Double)] = mode.includes(sourceID: CostSourceMode.claudeSourceID)
            ? report.modelsSorted.map { ($0.model, $0.usage.cost) }.filter { $0.1 > 0 }
            : []
        // Codex はモデル別内訳を持たないので、「Codex のみ」ではこのセクションが空になる。
        let cursor: [(String, Double)] = mode.includes(sourceID: CostSourceMode.cursorSourceID)
            ? cursorModelCosts : []

        switch breakdown {
        case .combined:
            var merged: [String: Double] = [:]
            for (m, c) in claude { merged[m, default: 0] += c }
            for (m, c) in cursor { merged[m, default: 0] += c }
            return merged.sorted { $0.value > $1.value }
                .map { ModelCostRow(source: nil, model: $0.key, cost: $0.value) }
        case .separated:
            var rows: [ModelCostRow] = []
            rows += claude.map { ModelCostRow(source: Self.claudeSourceLabel, model: $0.0, cost: $0.1) }
            rows += cursor.map { ModelCostRow(source: "Cursor", model: $0.0, cost: $0.1) }
            return rows
        }
    }


    /// 1 つのリストに並べるため、出どころを添えて持つ。
    public struct AdviceItem: Identifiable {
        public let source: String
        public let advice: RetokReport.Advice
        public var id: String { "\(source)|\(advice.key)" }

        public init(source: String, advice: RetokReport.Advice) {
            self.source = source
            self.advice = advice
        }
    }

    public nonisolated static func severityRank(_ severity: String) -> Int {
        switch severity {
        case "high": return 0
        case "medium", "warn": return 1
        case "low": return 2
        default: return 3
        }
    }

    public func adviceItems(for report: RetokReport) -> [AdviceItem] {
        let mode = settings.costSourceMode
        var items: [AdviceItem] = []
        if mode.includes(sourceID: CostSourceMode.claudeSourceID) {
            items += report.advice.map { AdviceItem(source: Self.claudeSourceLabel, advice: $0) }
        }
        if mode.includes(sourceID: CostSourceMode.cursorSourceID) {
            items += CursorAdvice.hints(for: cursorAdviceInput(for: report))
                .map { AdviceItem(source: CursorAdvice.sourceLabel, advice: $0) }
        }
        return items.sorted { lhs, rhs in
            let lRank = Self.severityRank(lhs.advice.severity)
            let rRank = Self.severityRank(rhs.advice.severity)
            if lRank != rRank { return lRank < rRank }
            if lhs.source != rhs.source { return lhs.source < rhs.source }
            return lhs.advice.key < rhs.advice.key
        }
    }

    /// Cursor の取得が劣化しているか（TF-0073 の `CostSnapshot.health`）。
    /// 劣化していれば金額は実態より小さいので、その数字を根拠にした助言はしない。
    /// `degradedSourceWarnings` と違いソース表示モードは見ない——ヒント側の絞り込みは
    public var cursorFetchDegraded: Bool {
        if case .degraded = driverHealthByID["cursor"] { return true }
        return false
    }

    private func cursorAdviceInput(for report: RetokReport) -> CursorAdvice.Input {
        let from = Self.reportWindowStart(days: report.periodDays)
        let cursorTotal = (driverDailyByID["cursor"] ?? [:])
            .filter { $0.key >= from }
            .values.reduce(0, +)
        return CursorAdvice.Input(
            modelCosts: driverModelByID["cursor"] ?? [:],
            cursorTotal: cursorTotal,
            claudeTotal: report.totals.cost,
            isDegraded: cursorFetchDegraded)
    }


    public struct TopSessionRow: Identifiable {
        public let id: String
        public let source: String
        public let title: String
        public let cost: Double
        public let isEstimated: Bool

        public init(id: String, source: String, title: String, cost: Double, isEstimated: Bool) {
            self.id = id
            self.source = source
            self.title = title
            self.cost = cost
            self.isEstimated = isEstimated
        }
    }

    public static let topSessionLimit = 3

    /// `costSourceMode` に従い、含めないソースの行は作らない（`claudeOnly` なら Cursor 行なし）。
    /// 二次ソースは driver が返した会話だけを並べる —— ローカル走査が空になる環境（#73）では
    public func topSessionRows(for report: RetokReport, limit: Int = topSessionLimit) -> [TopSessionRow] {
        let mode = settings.costSourceMode
        var rows: [TopSessionRow] = []
        if mode.includes(sourceID: CostSourceMode.claudeSourceID) {
            rows += report.topSessions.map {
                TopSessionRow(id: "\(Self.claudeSourceLabel)|\($0.session)",
                              source: Self.claudeSourceLabel,
                              title: $0.project, cost: $0.cost, isEstimated: false)
            }
        }
        let names = secondarySourceNames
        for (id, sessions) in driverSessionsByID where mode.includes(sourceID: id) {
            let source = names[id] ?? id
            rows += sessions.map {
                TopSessionRow(id: "\(id)|\($0.id)", source: source,
                              title: $0.title, cost: $0.cost, isEstimated: true)
            }
        }
        let sorted = rows
            .filter { $0.cost > 0 }
            .sorted { $0.cost == $1.cost ? $0.id < $1.id : $0.cost > $1.cost }
        return Array(sorted.prefix(limit))
    }
}
