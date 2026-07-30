import Foundation
import Combine

struct RepoUsage: Identifiable, Codable {
    var id: String { repo }
    let repo: String
    let org: String
    let genre: String
    /// 集計日 (YYYY-MM-DD)。複数日をまとめた集計では "" になる。
    let date: String
    let tools: [String: Int]
    let session: SessionMetrics
    let edits: [String: EditMetrics]

    var totalToolCalls: Int { tools.values.reduce(0, +) }
    var skillCalls: Int { tools.filter { $0.key.hasPrefix("Skill:") }.values.reduce(0, +) }
    var mcpCalls: Int { tools.filter { $0.key.hasPrefix("MCP:") }.values.reduce(0, +) }
    var subagentCalls: Int { tools.filter { $0.key.hasPrefix("Subagent:") }.values.reduce(0, +) }
    var promptCount: Int { session.prompt }
    var sessionCount: Int { session.instructionLoad }

    var topSkills: [(name: String, count: Int)] {
        tools.filter { $0.key.hasPrefix("Skill:") }
            .map { (String($0.key.dropFirst(6)), $0.value) }
            .sorted { $0.count > $1.count }
    }

    var topMCP: [(name: String, count: Int)] {
        tools.filter { $0.key.hasPrefix("MCP:") }
            .map { (shortMCPName(String($0.key.dropFirst(4))), $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func shortMCPName(_ raw: String) -> String {
        let parts = raw.split(separator: "_", maxSplits: 4, omittingEmptySubsequences: false)
            .filter { !$0.isEmpty }
        guard parts.count >= 3 else { return raw }
        return "\(parts[1])/\(parts[2])"
    }

    enum CodingKeys: String, CodingKey {
        case repo = "_repo"
        case org = "_org"
        case genre = "_genre"
        case date = "_date"
        case tools, session, edits
    }

    init(repo: String, org: String, genre: String, date: String,
         tools: [String: Int], session: SessionMetrics, edits: [String: EditMetrics]) {
        self.repo = repo
        self.org = org
        self.genre = genre
        self.date = date
        self.tools = tools
        self.session = session
        self.edits = edits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repo = try c.decodeIfPresent(String.self, forKey: .repo) ?? "unknown"
        org = try c.decodeIfPresent(String.self, forKey: .org) ?? "unknown"
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? "other"
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        tools = try c.decodeIfPresent([String: Int].self, forKey: .tools) ?? [:]
        session = try c.decodeIfPresent(SessionMetrics.self, forKey: .session) ?? SessionMetrics()
        edits = try c.decodeIfPresent([String: EditMetrics].self, forKey: .edits) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(repo, forKey: .repo)
        try c.encode(org, forKey: .org)
        try c.encode(genre, forKey: .genre)
        try c.encode(date, forKey: .date)
        try c.encode(tools, forKey: .tools)
        try c.encode(session, forKey: .session)
        try c.encode(edits, forKey: .edits)
    }

    /// 同一リポジトリの別日レコードを足し合わせて 1 つにまとめる。
    func merged(with other: RepoUsage) -> RepoUsage {
        var t = tools
        for (k, v) in other.tools { t[k, default: 0] += v }
        var e = edits
        for (k, v) in other.edits {
            var m = e[k] ?? EditMetrics()
            m.added += v.added
            m.deleted += v.deleted
            e[k] = m
        }
        var s = session
        s.prompt += other.session.prompt
        s.instructionLoad += other.session.instructionLoad
        return RepoUsage(repo: repo, org: org, genre: genre, date: "",
                         tools: t, session: s, edits: e)
    }
}

struct SessionMetrics: Codable {
    var prompt: Int = 0
    var instructionLoad: Int = 0

    enum CodingKeys: String, CodingKey {
        case prompt = "Prompt"
        case instructionLoad = "InstructionLoad"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try c.decodeIfPresent(Int.self, forKey: .prompt) ?? 0
        instructionLoad = try c.decodeIfPresent(Int.self, forKey: .instructionLoad) ?? 0
    }
}

struct EditMetrics: Codable {
    var added: Int = 0
    var deleted: Int = 0
}

struct GenreSummary: Identifiable {
    let genre: String
    var id: String { genre }
    var totalTools: Int = 0
    var skills: Int = 0
    var mcp: Int = 0
    var subagents: Int = 0
    var prompts: Int = 0
    var sessions: Int = 0
    var repos: [RepoUsage] = []
}

/// 1 日分の全リポジトリ合計。日次グラフ・利用割合の元データ。
struct DailyUsage: Identifiable {
    let date: String          // YYYY-MM-DD
    var id: String { date }
    var skills: Int = 0
    var mcp: Int = 0
    var subagents: Int = 0
    var prompts: Int = 0
    var sessions: Int = 0
    var editsAdded: Int = 0
    var editsDeleted: Int = 0

    var totalTools: Int { skills + mcp + subagents }

    /// 棒グラフ用の内訳（種別ごとの件数）。
    var breakdown: [(kind: String, count: Int)] {
        [("Skills", skills), ("MCP", mcp), ("Agents", subagents)]
    }

    /// 軸ラベル用の短い日付 (MM/DD)。
    var shortDate: String {
        let parts = date.split(separator: "-")
        return parts.count == 3 ? "\(parts[1])/\(parts[2])" : date
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var repos: [RepoUsage] = []
    @Published var genres: [GenreSummary] = []
    @Published var daily: [DailyUsage] = []
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    // retok によるコストレポート
    @Published private var loadedReport: RetokReport?

    /// DEBUG の「レポート未取得を再現」中は、アプリ全体から未取得（nil）に見せる。
    /// コスト・グラフ・読み込み中表示が起動直後とそろうよう、参照はすべてここを通す。
    var report: RetokReport? {
        get {
            #if DEBUG
            return DebugSettings.shared.simulatesMissingReport ? nil : loadedReport
            #else
            return loadedReport
            #endif
        }
        set { loadedReport = newValue }
    }
    @Published var retokError: String?
    /// retok 再解析（数秒かかる）の実行中フラグ。期間切り替え時のグラフに反映する。
    @Published var isReportLoading = false
    /// 連打時に古い結果が新しい結果を上書きしないようにする世代カウンタ。
    private var reportGeneration = 0
    /// 32 日集計（予算・日次平均）側の同じ用途のカウンタ。
    private var budgetGeneration = 0
    /// Cost タブの集計期間（日数）。最後に選んだ値を記憶する。
    @Published var reportDays: Int {
        didSet {
            if oldValue != reportDays {
                UserDefaults.standard.set(reportDays, forKey: Keys.reportDays)
                reloadReport()
            }
        }
    }
    /// 推移チャートの描画形式（日別バー / 累積折れ線）。純粋な表示切替なので再解析はしない。
    @Published var costChartStyle: CostChartStyle {
        didSet {
            if oldValue != costChartStyle {
                UserDefaults.standard.set(costChartStyle.rawValue, forKey: Keys.costChartStyle)
            }
        }
    }
    /// Tools タブの集計期間。最後に選んだ値を記憶する。
    @Published var toolsPeriod: PeriodFilter {
        didSet {
            if oldValue != toolsPeriod {
                UserDefaults.standard.set(toolsPeriod.rawValue, forKey: Keys.toolsPeriod)
                reaggregate()
            }
        }
    }

    /// 走査済みの生レコード（リポジトリ×日）。期間切り替え時の再集計元。
    private var allRecords: [RepoUsage] = []

    /// Codex CLI の日別使用量（CU-0009）。ログが無いマシンでは空のまま。
    @Published var codexDaily: [ProviderDayUsage] = []

    /// driver.id → (日付 → コスト)。ヒーロー・予算・グラフはここから合算する。
    /// reloadReport() と同じ期間で更新される（今日は常にこの範囲に含まれる）。
    /// private にしていないのは codexDaily と同じ理由 — テストから直接注入できるようにするため。
    /// 読み書きするメソッド・計算プロパティは下の `extension UsageStore` にまとめている
    /// （extension は保持型プロパティを持てないので、この 2 つだけ本体に残る）。
    @Published var driverDailyByID: [String: [String: Double]] = [:]

    /// driver.id → (モデル → 期間コスト)。レポート期間のモデル別内訳用。
    @Published var driverModelByID: [String: [String: Double]] = [:]

    /// ScreenshotRenderer が UsageStore の初期化前に UserDefaults へ直接書くため公開している。
    nonisolated static let costChartStyleKey = "costChartStyle"

    private enum Keys {
        static let reportDays = "reportDays"
        static let costChartStyle = UsageStore.costChartStyleKey
        static let toolsPeriod = "toolsPeriod"
    }

    init() {
        let defaults = UserDefaults.standard
        reportDays = Self.sanitizedReportDays(defaults.integer(forKey: Keys.reportDays))
        costChartStyle = CostChartStyle(
            rawValue: defaults.string(forKey: Keys.costChartStyle) ?? "") ?? .daily
        toolsPeriod = PeriodFilter(rawValue: defaults.string(forKey: Keys.toolsPeriod) ?? "")
            ?? .days30
    }

    /// 保存済みの集計期間を現在の選択肢に丸める。かつて存在した「今日 (1)」は近い 7 日へ、
    /// 未知の値は既定の 30 日に倒す。
    nonisolated static func sanitizedReportDays(_ stored: Int) -> Int {
        if [7, 30].contains(stored) { return stored }
        return stored == 1 ? 7 : 30
    }

    // 予算期間内の消費額（ソース別。表示は costSourceMode で合成する）
    @Published private var reportedClaudeBudgetSpend: Double = 0
    @Published private var reportedCursorBudgetSpend: Double = 0

    /// DEBUG では読み取りだけデバッグ上書きを通す。書き込みは常に実データ側へ入るので、
    /// 上書きを OFF にすればそのまま元の数字に戻る。
    var budgetSpend: Double {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            if let override = DebugSettings.shared.month { return override }
            #endif
            return Self.displayedSpend(
                claude: reportedClaudeBudgetSpend,
                cursor: reportedCursorBudgetSpend,
                mode: AppSettings.shared.costSourceMode)
        }
        set {
            // スクリーンショット用フィクスチャと予算オフ時のクリア。合算を Claude 側に載せ、
            // Cursor 側は 0 にする（表示モードが合算なら見た目は同じ）。
            if reportedClaudeBudgetSpend != newValue { reportedClaudeBudgetSpend = newValue }
            if reportedCursorBudgetSpend != 0 { reportedCursorBudgetSpend = 0 }
        }
    }

    var claudeBudgetSpend: Double { reportedClaudeBudgetSpend }
    var cursorBudgetSpend: Double { reportedCursorBudgetSpend }

    /// テスト・スクリーンショットからソース別予算を直接入れる。
    func setBudgetSpend(claude: Double, cursor: Double) {
        if reportedClaudeBudgetSpend != claude { reportedClaudeBudgetSpend = claude }
        if reportedCursorBudgetSpend != cursor { reportedCursorBudgetSpend = cursor }
    }

    // 過去 30 日の日次平均コスト（未算出・レポート未取得なら 0）
    @Published private var reportedDailyAverage: Double = 0

    /// メニューバーの割合表示で「いつもの 1 日」を表す分母。budgetSpend と同じ 32 日集計から出す。
    var dailyAverage30: Double {
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

    // 予算期間内で実際にコストが出た日数（未算出なら 0）
    @Published private var reportedActiveDays = 0

    /// 予算期間内でコストが出た日数。`dailyAverage30`（稼働 1 日あたり）と掛けて
    /// 「平均ペースなら今日までにいくら使っているか」を出すのに使う。
    var activeDaysInPeriod: Int {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            #endif
            return reportedActiveDays
        }
        set { if reportedActiveDays != newValue { reportedActiveDays = newValue } }
    }

    /// 日次コストの 1 日あたり平均。今日は途中なので除き、実績のある日だけで割る
    /// （記録の無い日も数えると、使い始めた直後の平均が不当に小さくなる）。
    static func dailyAverage(in daily: [String: RetokReport.DailyCost],
                             since start: String, before today: String) -> Double {
        let window = daily.filter { $0.key >= start && $0.key < today && $0.value.cost > 0 }
        guard !window.isEmpty else { return 0 }
        return window.values.reduce(0) { $0 + $1.cost } / Double(window.count)
    }

    /// 期間内でコストが出た日数。dailyAverage と同じ「実績のある日」の数え方にそろえる。
    static func activeDays(in daily: [String: RetokReport.DailyCost], since start: String) -> Int {
        daily.filter { $0.key >= start && $0.value.cost > 0 }.count
    }

    /// メニューバー表示の組み立てに渡す入力。ステータス項目と設定のライブプレビューで共用する。
    /// 別の表現で試算したいときは、返り値の `representation` を差し替える。
    func menuBarInput() -> MenuBarInput {
        let settings = AppSettings.shared
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
                dailyLimit: settings.dailyBudgetLimit, monthlyLimit: settings.budgetLimit,
                dailyAverage: dailyAverage30, activeDays: activeDaysInPeriod),
            dailyLimit: settings.dailyBudgetLimit,
            monthlyLimit: settings.budgetLimit,
            todayClaude: claudeTodayCost,
            todayCursor: cursorTodayCost,
            monthClaude: claudeBudgetSpend,
            monthCursor: cursorBudgetSpend,
            // ゲージは側ごとに塗り分ける。今日だけしきい値を越えたら今日のゲージだけが変わる。
            todayLevel: dailyBudgetLevel,
            monthLevel: budgetLevel)
    }

    /// 月間予算のレベル（予算オフなら nil）。
    var budgetLevel: BudgetLevel? {
        let settings = AppSettings.shared
        guard settings.budgetLimit > 0 else { return nil }
        return BudgetMonitor.level(spend: budgetSpend, limit: settings.budgetLimit,
                                   warnPercent: settings.budgetWarnPercent)
    }

    /// 日次予算のレベル（予算オフなら nil）。今日のコストと比較する。
    var dailyBudgetLevel: BudgetLevel? {
        let settings = AppSettings.shared
        guard settings.dailyBudgetLimit > 0 else { return nil }
        return BudgetMonitor.level(spend: todayCost, limit: settings.dailyBudgetLimit,
                                   warnPercent: settings.budgetWarnPercent)
    }

    /// アイコン色に使う総合レベル。月間・日次の悪い方。
    var combinedBudgetLevel: BudgetLevel? {
        switch (budgetLevel, dailyBudgetLevel) {
        case let (m?, d?): return max(m, d)
        case let (m?, nil): return m
        case let (nil, d?): return d
        case (nil, nil): return nil
        }
    }

    /// トランスクリプト走査（バックグラウンド）→ 集計反映。retok も並行して実行する。
    func reload() {
        guard !isLoading else { return }
        isLoading = true
        reloadReport()
        reloadBudget()
        // Cursor の価格表を（インストールされていて、当日未取得なら）取り直す。今回の集計には
        // 間に合わなくてもよい — 取れれば次回以降の CursorPricing.cost() から新しい表を使う。
        Task { await CursorPricingService.refreshIfNeeded() }
        // 走査元はバックグラウンドスレッドから @MainActor の設定を触らないよう、ここで解決して渡す。
        let projectsDir = AppSettings.shared.claudeDirectoryURL.appendingPathComponent("projects")
        Task.detached(priority: .userInitiated) {
            let records = TranscriptScanner.scan(projectsDir: projectsDir)
            let codex = CodexUsageReader.scan()
            await MainActor.run { [weak self] in
                self?.apply(records: records)
                self?.codexDaily = codex
                self?.isLoading = false
            }
        }
    }

    // MARK: - プロバイダ比較（CU-0009）

    /// Tools タブの期間で絞った Codex の合計。ログが無ければ nil（セクション非表示）。
    var codexSummary: (sessions: Int, input: Int, output: Int, lastDate: String)? {
        guard let last = codexDaily.last else { return nil }
        let window = codexDaily.filter { toolsPeriod.includes(date: $0.date) }
        return (sessions: window.reduce(0) { $0 + $1.sessions },
                input: window.reduce(0) { $0 + $1.inputTokens },
                output: window.reduce(0) { $0 + $1.outputTokens },
                lastDate: last.date)
    }

    /// retok レポートを再取得する（設定変更や言語変更からも呼べるよう公開）。
    func reloadReport() {
        let days = reportDays
        let lang = AppSettings.shared.language.resolved
        // Claude ディレクトリが既定と異なる場合のみ retok に projects を明示指定する。
        let claudeDir = AppSettings.shared.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        reportGeneration += 1
        let generation = reportGeneration
        isReportLoading = true
        // stale-while-revalidate: ディスクの前回結果を先に出し、裏の再解析（数秒）が終わり
        // 次第差し替える。期間切替や再起動直後に画面がスピナーへ戻らない。
        let cacheKeyPath = claudeDir.standardizedFileURL.path
        if let cached = ReportCache.shared.load(days: days, lang: lang, projectsPath: cacheKeyPath) {
            report = cached
        }
        let from = Self.reportWindowStart(days: days)
        let to = Self.dateString(Date())
        Task {
            // retok（外部プロセス）と二次ソース（SQLite）は互いに独立な I/O なので並行して走らせる。
            async let retokTask = RetokService.run(days: days, lang: lang, projectsDir: projectsOverride, provider: "claude")
            async let driverTask = self.fetchDriverDaily(from: from, to: to)

            do {
                let r = try await retokTask
                guard generation == self.reportGeneration else { return }
                self.report = r
                ReportCache.shared.save(r, days: days, lang: lang, projectsPath: cacheKeyPath)
                self.retokError = nil
            } catch {
                guard generation == self.reportGeneration else { return }
                self.retokError = error.localizedDescription
            }
            self.isReportLoading = false

            // retok の成否に関わらず、二次ソースは独立に反映する（失敗しても 0 になるだけ）。
            let byID = await driverTask
            guard generation == self.reportGeneration else { return }
            self.driverDailyByID = byID
            // ダッシュボード取得済みならキャッシュヒット。モデル別内訳を同じ期間で載せる。
            let cursorPath = CursorCostDriver.defaultStateDBURL.path
            if let snap = await CursorDashboardService.fetchSnapshot(
                from: from, to: to, dbPath: cursorPath
            ) {
                self.driverModelByID = ["cursor": snap.byModel]
            } else if byID["cursor"] == nil {
                self.driverModelByID = [:]
            }
        }
    }

    /// 予算期間内の消費額を再計算する。表示用レポート（7d/30d 切替）とは独立に、
    /// 暦月の最大長（31 日）を必ずカバーする 32 日分で retok を実行する。
    func reloadBudget() {
        let settings = AppSettings.shared
        // 集計が不要になった場合も含めて先に世代を進める。そうしないと、実行中の集計が
        // 「0 にした」あとから古い値を書き戻してしまう。
        budgetGeneration += 1
        let generation = budgetGeneration
        // 月間予算オフでも、メニューバーが今月のコストや日次平均を求めるなら集計は必要。
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
        Task {
            async let retokTask = RetokService.run(days: 32, lang: "en", projectsDir: projectsOverride, provider: "claude")
            async let driverTask = self.fetchDriverDaily(from: start, to: today)

            // retok が失敗しても（python3 なし等）二次ソースの結果は捨てない — reloadReport() と
            // 同じく、retok の成否と二次ソースの反映は独立にする（CLAUDE.md ルール 4）。
            let r = try? await retokTask
            // 設定を連続で変えると 32 日集計が並走しうる。古い結果で新しい結果を上書きしない。
            guard generation == self.budgetGeneration else { return }

            let claudeSpend = r?.daily
                .filter { $0.key >= start }
                .values.reduce(0) { $0 + $1.cost } ?? 0
            let driverByID = await driverTask
            let driverSpend = driverByID.values
                .reduce(0) { $0 + $1.values.reduce(0, +) }
            if self.reportedClaudeBudgetSpend != claudeSpend {
                self.reportedClaudeBudgetSpend = claudeSpend
            }
            if self.reportedCursorBudgetSpend != driverSpend {
                self.reportedCursorBudgetSpend = driverSpend
            }
            // reloadReport より予算窓の方が広いことがあるので、日別も予算側の結果で補完する。
            for (id, daily) in driverByID {
                var merged = self.driverDailyByID[id] ?? [:]
                for (date, cost) in daily { merged[date] = cost }
                self.driverDailyByID[id] = merged
            }

            // 稼働日数・日次平均は retok 専用の指標。budgetSpend と違い二次ソースの分が無いので、
            // retok が失敗した回は更新せず直前の値を残す（中途半端な値を作らない）。
            guard let r else { return }
            self.activeDaysInPeriod = Self.activeDays(in: r.daily, since: start)
            let now = Date()
            // 平均は今日を含めないので、periodStart（今日を含む 30 日 = −29 日）とは 1 日ずれる。
            // 昨日から遡って 30 日ぶんを窓にする。
            let averageStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            self.dailyAverage30 = Self.dailyAverage(in: r.daily,
                                                    since: Self.dateString(averageStart),
                                                    before: Self.dateString(now))
        }
    }

    private func apply(records: [RepoUsage]) {
        allRecords = records
        reaggregate()

        // --- 日付単位に集約（日次グラフ用・全期間。グラフの窓は trendDays が持つ） ---
        var dayMap: [String: DailyUsage] = [:]
        for r in records where !r.date.isEmpty {
            var d = dayMap[r.date] ?? DailyUsage(date: r.date)
            d.skills += r.skillCalls
            d.mcp += r.mcpCalls
            d.subagents += r.subagentCalls
            d.prompts += r.promptCount
            d.sessions += r.sessionCount
            for v in r.edits.values {
                d.editsAdded += v.added
                d.editsDeleted += v.deleted
            }
            dayMap[r.date] = d
        }
        daily = dayMap.values.sorted { $0.date < $1.date }

        lastUpdated = Date()
    }

    /// Tools タブの期間（toolsPeriod）でレコードを絞り、リポジトリ・ジャンル集計を作り直す。
    /// 日次グラフ（daily）と Skill 棚卸しは意図的に全期間のまま。
    private func reaggregate() {
        let filtered = allRecords.filter { toolsPeriod.includes(date: $0.date) }

        // --- リポジトリ単位に集約（日付をまたいでマージ） ---
        var repoMap: [String: RepoUsage] = [:]
        for r in filtered {
            let key = "\(r.org)/\(r.repo)"
            repoMap[key] = repoMap[key].map { $0.merged(with: r) } ?? r
        }
        repos = repoMap.values
            .map { RepoUsage(repo: $0.repo, org: $0.org, genre: $0.genre, date: "",
                             tools: $0.tools, session: $0.session, edits: $0.edits) }
            .sorted { $0.totalToolCalls > $1.totalToolCalls }

        // --- ジャンル単位に集約 ---
        var genreMap: [String: GenreSummary] = [:]
        for repo in repos {
            var g = genreMap[repo.genre] ?? GenreSummary(genre: repo.genre)
            g.totalTools += repo.totalToolCalls
            g.skills += repo.skillCalls
            g.mcp += repo.mcpCalls
            g.subagents += repo.subagentCalls
            g.prompts += repo.promptCount
            g.sessions += repo.sessionCount
            g.repos.append(repo)
            genreMap[repo.genre] = g
        }
        genres = genreMap.values.sorted { $0.totalTools > $1.totalTools }
    }

    var totalSkills: Int { repos.reduce(0) { $0 + $1.skillCalls } }
    var totalMCP: Int { repos.reduce(0) { $0 + $1.mcpCalls } }
    var totalSubagents: Int { repos.reduce(0) { $0 + $1.subagentCalls } }
    var totalPrompts: Int { repos.reduce(0) { $0 + $1.promptCount } }
    var totalSessions: Int { repos.reduce(0) { $0 + $1.sessionCount } }

    // MARK: - 今日 / 昨日

    /// 日付キー用のフォーマッタ。状態を持たないので使い回す
    /// （メニューバーの再描画ごとに数回通るため、毎回作ると無駄が積む）。
    /// DateFormatter は Sendable なので、dateString() を nonisolated にしても問題なく触れる。
    private nonisolated static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// ローカルタイムの YYYY-MM-DD 文字列。集計キーの書式はここが基準。
    /// actor 状態に触れない純粋関数なので nonisolated — CursorUsageReader のようにバック
    /// グラウンドから同期的に呼びたい場所からも await なしで使える（PopoverView.money と同じ扱い）。
    nonisolated static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// 表示窓の開始日（end を含む days 日間）。retok の --days と同じ数え方。
    nonisolated static func reportWindowStart(days: Int, endingOn end: Date = Date()) -> String {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        return dateString(start)
    }

    /// 今日の集計（無ければ空の DailyUsage）。
    var today: DailyUsage {
        let key = Self.dateString(Date())
        return daily.first { $0.date == key } ?? DailyUsage(date: key)
    }

    /// 今日の Claude（retok）コスト。
    var claudeTodayCost: Double {
        report?.cost(on: Self.dateString(Date())) ?? 0
    }

    /// 今日の Cursor 等二次ソースコスト。
    var cursorTodayCost: Double {
        driverDaily[Self.dateString(Date())] ?? 0
    }

    /// 今日の表示コスト。`costSourceMode` に従って Claude / Cursor を含める。
    /// レポート未取得も 0 とみなす（「不明」は出さず、retok 失敗はエラー表示が伝える）。
    var todayCost: Double {
        #if DEBUG
        if let override = DebugSettings.shared.today { return override }
        #endif
        return Self.displayedSpend(
            claude: claudeTodayCost,
            cursor: cursorTodayCost,
            mode: AppSettings.shared.costSourceMode)
    }

    /// ソース表示モードに従って 2 源を合成する。
    nonisolated static func displayedSpend(
        claude: Double, cursor: Double, mode: CostSourceMode
    ) -> Double {
        var total = 0.0
        if mode.includesClaude { total += claude }
        if mode.includesCursor { total += cursor }
        return total
    }

    /// 昨日の集計（無ければ nil）。前日比の算出に使う。
    var yesterday: DailyUsage? {
        guard let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let key = Self.dateString(y)
        return daily.first { $0.date == key }
    }

    /// 直近 `days` 日分の日次データ（古い順）。グラフ用。
    func recentDaily(_ days: Int) -> [DailyUsage] {
        Array(daily.suffix(days))
    }

    /// 全リポジトリ横断で集計した、よく使う Skill / MCP の降順ランキング。
    var topSkills: [(name: String, count: Int)] { aggregatedTools(prefix: "Skill:", short: false) }
    var topMCP: [(name: String, count: Int)] { aggregatedTools(prefix: "MCP:", short: true) }

    private func aggregatedTools(prefix: String, short: Bool) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for repo in repos {
            let list = short ? repo.topMCP : repo.topSkills
            for item in list { counts[item.name, default: 0] += item.count }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

}

// MARK: - CostDriver 統合（Cursor 等、Claude/retok に合算する二次ソース）
//
// costDrivers・driverDailyByID（保持型プロパティなので extension には置けない）だけを本体に
// 残し、そこから導出できるものはすべてここにまとめている。新しい CostDriver を足すときは
// costDrivers 配列に 1 行足すだけで、この extension 側は変更不要。

extension UsageStore {
    /// Claude（retok）に合算する二次コスト源。新しいソースを足すときはここに 1 行足すだけでよい。
    /// 全インスタンス共通なので static — extension はインスタンス保持型プロパティを持てないが、
    /// static は持てる。
    private static let costDrivers: [CostDriver] = [CursorCostDriver(), CodexCostDriver()]

    /// driver.id → 表示名。グラフの色分け（PopoverView）で使う。
    static var secondarySourceNames: [String: String] {
        Dictionary(uniqueKeysWithValues: costDrivers.map { ($0.id, $0.displayName) })
    }

    private func driverCost(id: String, on date: String) -> Double {
        driverDailyByID[id]?[date] ?? 0
    }

    /// 二次ソース合算の日別コスト（Claude を含まない）。グラフの合算描画に使う。
    var driverDaily: [String: Double] {
        var merged: [String: Double] = [:]
        for byDate in driverDailyByID.values {
            for (date, cost) in byDate { merged[date, default: 0] += cost }
        }
        return merged
    }

    /// 今日ぶんの二次ソース内訳（Claude は含まない）。デバッグ表示・テスト用。データが無い/0 の
    /// ソースは出さない（ヒーローの内訳キャプションは $0 も明示するため合算値を直接使う）。
    var driverBreakdown: [(name: String, cost: Double)] {
        let today = Self.dateString(Date())
        return Self.costDrivers.compactMap { driver in
            let cost = driverCost(id: driver.id, on: today)
            return cost > 0 ? (driver.displayName, cost) : nil
        }
    }

    /// costDrivers のうち利用可能なものだけを問い合わせ、id → (日付 → コスト) にまとめる。
    /// reloadReport()/reloadBudget() が別々の期間で呼ぶ共通処理。private でも同一ファイル内の
    /// 本体（reloadReport 等）から呼べる（同一ファイル内の extension は private を共有する）。
    private func fetchDriverDaily(from: String, to: String) async -> [String: [String: Double]] {
        var byID: [String: [String: Double]] = [:]
        for driver in Self.costDrivers where driver.isAvailable {
            byID[driver.id] = await driver.dailyCosts(from: from, to: to)
        }
        return byID
    }

    // MARK: - グラフ用の積み上げ行（PopoverView は描画に専念させ、集計はここに置く）

    /// グラフ 1 本ぶんの行。同じ日付でも Claude と二次ソースは別行にして BarMark を積み上げる。
    struct ChartRow: Identifiable {
        let date: String
        let source: String
        let cost: Double
        var id: String { date + source }
    }

    static let claudeSourceLabel = "Claude"

    /// retok の日別コストと二次ソース（driverDailyByID）を積み上げグラフ用の行に変換する。
    /// 日付は全ソースの合併集合を使う（Claude が $0 の日でも Cursor/Codex だけ使った日は落とさない）。
    /// コストが 0 の行は積まない（積み上げバーに幅 0 の区切りが入るのを避ける）。
    /// `costSourceMode` で片方だけ選んでいるときはその側の系列だけ出す。二次ソースは driver ごとに
    /// 別の行・別の色にする（Cursor と Codex を 1 本の "Cursor 等" に混ぜない）。
    func chartRows(for report: RetokReport) -> [ChartRow] {
        let mode = AppSettings.shared.costSourceMode
        var claudeByDate: [String: Double] = [:]
        for day in report.dailySorted { claudeByDate[day.date] = day.cost }
        // 二次ソース側は表示窓で絞る。reloadBudget が予算窓（表示窓より広いことがある）の
        // 日別を driverDailyByID に補完するため、絞らないと「7日」のグラフに 30 日分が漏れる。
        let from = Self.reportWindowStart(days: report.periodDays)
        var dates = Set<String>()
        if mode.includesClaude { dates.formUnion(claudeByDate.keys) }
        if mode.includesCursor {
            for byDate in driverDailyByID.values { dates.formUnion(byDate.keys.filter { $0 >= from }) }
        }
        let driverNames = Self.secondarySourceNames
        return dates.sorted().flatMap { date -> [ChartRow] in
            var rows: [ChartRow] = []
            if mode.includesClaude, let claude = claudeByDate[date], claude > 0 {
                rows.append(ChartRow(date: date, source: Self.claudeSourceLabel, cost: claude))
            }
            if mode.includesCursor {
                for (id, byDate) in driverDailyByID {
                    guard date >= from, let cost = byDate[date], cost > 0 else { continue }
                    rows.append(ChartRow(date: date, source: driverNames[id] ?? id, cost: cost))
                }
            }
            return rows
        }
    }

    /// 累積折れ線の 1 点。その日までの合算コスト。
    struct CumulativePoint: Identifiable {
        let date: String
        let total: Double
        var id: String { date }
    }

    /// 表示窓の全日付（古い順）。累積線の X 軸はカテゴリなので、コストの無い日を落とすと
    /// 日付が詰まって傾き＝ペースが歪む。この列で全日を点として埋める。
    nonisolated static func windowDates(days: Int, endingOn end: Date = Date()) -> [String] {
        let cal = Calendar.current
        return (0..<days).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: end).map(dateString)
        }
    }

    /// 積み上げ行（chartRows）を `dates` の並びに沿った累積列に畳む。ソースは分けず合計
    /// 1 本にする（内訳は日別バーの担当。累積まで線を分けても判断は変わらない）。
    /// コストの無い日は前日の値を引き継ぎ、dates に無い日付の行は数えない。
    nonisolated static func cumulativeRows(from rows: [ChartRow],
                                           over dates: [String]) -> [CumulativePoint] {
        var byDate: [String: Double] = [:]
        for row in rows { byDate[row.date, default: 0] += row.cost }
        var running = 0.0
        return dates.map { date in
            running += byDate[date] ?? 0
            return CumulativePoint(date: date, total: running)
        }
    }

    /// 暦月予算の着地予測。月初からの消費を経過日数で割った日次ペースを月末まで伸ばす。
    /// 消費が無い（外挿の根拠が無い）ときは予測を出さない。
    nonisolated static func monthEndProjection(
        spend: Double, now: Date = Date(), calendar: Calendar = .current
    ) -> Double? {
        guard spend > 0,
              let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count
        else { return nil }
        return spend / Double(calendar.component(.day, from: now)) * Double(daysInMonth)
    }

    /// 累積ビューに添える予算の注釈。予算の窓と表示の窓の対応はここで 1 回だけ判定する
    /// （ビュー側の別々の条件に散らすと、期間の選択肢が増えたとき片方だけ直る事故が起きる）。
    enum BudgetChartAnnotation {
        /// 予算窓と表示窓が一致している — 上限の参照線が引ける。
        case referenceLine(limit: Double)
        /// 暦月予算 — 窓はローリング表示と一致しないが、月末着地の予測なら窓に依存しない。
        case monthEndProjection(amount: Double)
    }

    var cumulativeBudgetAnnotation: BudgetChartAnnotation? {
        let settings = AppSettings.shared
        guard settings.budgetLimit > 0 else { return nil }
        switch settings.budgetPeriod {
        case .rolling30:
            return reportDays == 30 ? .referenceLine(limit: settings.budgetLimit) : nil
        case .calendarMonth:
            return Self.monthEndProjection(spend: budgetSpend)
                .map { .monthEndProjection(amount: $0) }
        }
    }

    // MARK: - モデル別内訳

    /// モデル 1 行。結合一覧でもソース別一覧でも同じ形。
    struct ModelCostRow: Identifiable {
        let source: String?
        let model: String
        let cost: Double
        var id: String { "\(source ?? "all")|\(model)" }
    }

    /// レポート期間の Cursor モデル別コスト（ダッシュボード由来。無いときは空）。
    var cursorModelCosts: [(model: String, cost: Double)] {
        (driverModelByID["cursor"] ?? [:])
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    /// 期間合計（チャート下のキャプション用）。ソース表示モードに従う。
    /// 二次ソースは chartRows と同じ理由で表示窓に絞る（予算窓の補完分を数えない）。
    func periodTotalCost(for report: RetokReport) -> Double {
        let from = Self.reportWindowStart(days: report.periodDays)
        let cursor = driverDaily.filter { $0.key >= from }.values.reduce(0, +)
        return Self.displayedSpend(
            claude: report.totals.cost, cursor: cursor,
            mode: AppSettings.shared.costSourceMode)
    }

    /// 「モデル別」セクション用の行。ソースフィルタと内訳モードに従う。
    func modelCostRows(for report: RetokReport) -> [ModelCostRow] {
        let mode = AppSettings.shared.costSourceMode
        let breakdown = AppSettings.shared.costModelBreakdownMode
        let claude: [(String, Double)] = mode.includesClaude
            ? report.modelsSorted.map { ($0.model, $0.usage.cost) }.filter { $0.1 > 0 }
            : []
        let cursor: [(String, Double)] = mode.includesCursor ? cursorModelCosts : []

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
            // cursorModelCosts は driverModelByID["cursor"] 専用（Codex はまだモデル別内訳を持たない）
            // ので "Cursor" と実名を出す。複数 driver が持つようになったら見直す。
            rows += cursor.map { ModelCostRow(source: "Cursor", model: $0.0, cost: $0.1) }
            return rows
        }
    }
}
