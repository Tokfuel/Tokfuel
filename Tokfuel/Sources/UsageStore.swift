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
    /// Cost タブの集計期間（日数。1 = 今日のみ）。最後に選んだ値を記憶する。
    @Published var reportDays: Int {
        didSet {
            if oldValue != reportDays {
                UserDefaults.standard.set(reportDays, forKey: Keys.reportDays)
                reloadReport()
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

    private enum Keys {
        static let reportDays = "reportDays"
        static let toolsPeriod = "toolsPeriod"
    }

    init() {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: Keys.reportDays)
        reportDays = [1, 7, 30].contains(stored) ? stored : 30
        toolsPeriod = PeriodFilter(rawValue: defaults.string(forKey: Keys.toolsPeriod) ?? "")
            ?? .days30
    }

    // 予算期間内の消費額（未算出・レポート未取得なら 0）
    @Published private var reportedBudgetSpend: Double = 0

    /// DEBUG では読み取りだけデバッグ上書きを通す。書き込みは常に実データ側へ入るので、
    /// 上書きを OFF にすればそのまま元の数字に戻る。
    var budgetSpend: Double {
        get {
            #if DEBUG
            if DebugSettings.shared.simulatesMissingMonth { return 0 }
            return DebugSettings.shared.month ?? reportedBudgetSpend
            #else
            return reportedBudgetSpend
            #endif
        }
        set { reportedBudgetSpend = newValue }
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
        Task {
            do {
                let r = try await RetokService.run(days: days, lang: lang, projectsDir: projectsOverride)
                guard generation == self.reportGeneration else { return }
                self.report = r
                self.retokError = nil
            } catch {
                guard generation == self.reportGeneration else { return }
                self.retokError = error.localizedDescription
            }
            self.isReportLoading = false
        }
    }

    /// 予算期間内の消費額を再計算する。表示用レポート（7d/30d 切替）とは独立に、
    /// 暦月の最大長（31 日）を必ずカバーする 32 日分で retok を実行する。
    func reloadBudget() {
        let settings = AppSettings.shared
        // 月間予算オフでも、メニューバーが今月のコスト表示なら消費額は必要。
        guard settings.budgetLimit > 0 || settings.menuBarDisplay.showsMonthlyCost else {
            budgetSpend = 0
            return
        }
        // 予算オフで表示だけ必要な場合は「今月（1 日から）」で数える。
        let period = settings.budgetLimit > 0 ? settings.budgetPeriod : .calendarMonth
        let claudeDir = settings.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        Task {
            guard let r = try? await RetokService.run(days: 32, lang: "en",
                                                      projectsDir: projectsOverride) else { return }
            let start = BudgetMonitor.periodStart(for: period)
            self.budgetSpend = r.daily
                .filter { $0.key >= start }
                .values.reduce(0) { $0 + $1.cost }
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

    /// ローカルタイムの YYYY-MM-DD 文字列。レポートの日次キーと必ず一致するよう
    /// RetokTime に委譲する（書式の基準はそちら）。
    static func dateString(_ date: Date) -> String {
        RetokTime.localDayString(date)
    }

    /// 今日の集計（無ければ空の DailyUsage）。
    var today: DailyUsage {
        let key = Self.dateString(Date())
        return daily.first { $0.date == key } ?? DailyUsage(date: key)
    }

    /// 今日のコスト。レポート未取得（起動直後・解析前）も、今日の行が無い日も 0 とみなす。
    /// 「不明」を金額欄に出さない代わりに、retok が失敗した事実は Cost タブのエラー表示が伝える。
    var todayCost: Double {
        #if DEBUG
        return DebugSettings.shared.today ?? reportedTodayCost
        #else
        return reportedTodayCost
        #endif
    }

    private var reportedTodayCost: Double {
        report?.cost(on: Self.dateString(Date())) ?? 0
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
