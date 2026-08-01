import Foundation
import Combine

/// 1 日分のClaude Code利用回数。コストはretokのレポートを正とする。
struct DailyUsage: Identifiable, Codable, Sendable, Equatable {
    let date: String          // YYYY-MM-DD
    var id: String { date }
    var prompts: Int = 0
    var sessions: Int = 0
}

@MainActor
final class UsageStore: ObservableObject {
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
    private var reportTask: Task<Void, Never>?
    /// 追従モードの軽い更新（reloadToday）。重い集計とは別に持ち、互いに打ち消し合わせない。
    private var todayTask: Task<Void, Never>?
    private var budgetTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    /// ポップオーバーの集計期間（暦ベース）。最後に選んだ値を記憶する。
    @Published var reportPeriod: ReportPeriod {
        didSet {
            if oldValue != reportPeriod {
                defaults.set(reportPeriod.rawValue, forKey: Keys.reportPeriod)
                reloadReport()
            }
        }
    }
    /// 推移チャートの描画形式（日別バー / 累積折れ線）。純粋な表示切替なので再解析はしない。
    @Published var costChartStyle: CostChartStyle {
        didSet {
            if oldValue != costChartStyle {
                defaults.set(costChartStyle.rawValue, forKey: Keys.costChartStyle)
            }
        }
    }
    private let settings: AppSettings
    private let defaults: UserDefaults
    /// Claude（retok）に合算する二次コスト源。テストではスタブを注入できる。
    private let costDrivers: [any CostDriver]

    /// driver.id → (日付 → コスト)。ヒーロー・予算・グラフはここから合算する。
    /// reloadReport() と同じ期間で更新される（今日は常にこの範囲に含まれる）。
    /// private にしていないのは、表示モデルのテストから直接注入できるようにするため。
    /// 読み書きするメソッド・計算プロパティは下の `extension UsageStore` にまとめている
    /// （extension は保持型プロパティを持てないので、この 2 つだけ本体に残る）。
    @Published var driverDailyByID: [String: [String: Double]] = [:]

    /// driver.id → (モデル → 期間コスト)。レポート期間のモデル別内訳用。
    @Published var driverModelByID: [String: [String: Double]] = [:]

    /// driver.id → 直近の取得の確度。金額 0 が「使っていない」なのか「取れなかった」なのかを
    /// ポップオーバーで書き分けるために持つ（金額そのものは driverDailyByID 側）。
    @Published var driverHealthByID: [String: CostSnapshot.Health] = [:]

    /// サインインボタンを押したあと、次にポップオーバーを開いたら 1 度だけ取り直す合図。
    /// 「劣化しているなら開くたび取り直す」にはしない——retok の再実行を伴うので、
    /// ユーザーが実際にサインインしに行った回だけに限る。
    @Published var awaitingSignInRecheck = false

    /// driver.id → セッション（会話）別の内訳。「高コストのセッション」で Claude の
    /// retok セッションとマージする。セッションを識別できない driver は現れない。
    @Published var driverSessionsByID: [String: [CostSnapshot.Session]] = [:]

    /// ScreenshotRenderer が UsageStore の初期化前に UserDefaults へ直接書くため公開している。
    nonisolated static let costChartStyleKey = "costChartStyle"
    nonisolated static let reportPeriodKey = "reportPeriod"
    /// 旧ローリング日数。新キー未設定時の移行読み取り専用。もう書かない。
    nonisolated static let legacyReportDaysKey = "reportDays"

    private enum Keys {
        static let reportPeriod = UsageStore.reportPeriodKey
        static let legacyReportDays = UsageStore.legacyReportDaysKey
        static let costChartStyle = UsageStore.costChartStyleKey
    }

    init(
        settings: AppSettings = .shared,
        defaults: UserDefaults = .standard,
        costDrivers: [any CostDriver] = [CursorCostDriver(), CodexCostDriver()]
    ) {
        self.settings = settings
        self.defaults = defaults
        self.costDrivers = costDrivers
        reportPeriod = Self.resolvedReportPeriod(in: defaults)
        costChartStyle = CostChartStyle(
            rawValue: defaults.string(forKey: Keys.costChartStyle) ?? "") ?? .daily
    }

    /// 新キーがあればそれを使い、無ければ旧 `reportDays` から暦期間へ移す。既定は「今月」。
    nonisolated static func resolvedReportPeriod(in defaults: UserDefaults) -> ReportPeriod {
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

    // 予算期間内の消費額（ソース id 別。表示は costSourceMode で合成する）
    @Published private var reportedBudgetSpendBySource: [String: Double] = [:]

    /// DEBUG では読み取りだけデバッグ上書きを通す。書き込みは常に実データ側へ入るので、
    /// 上書きを OFF にすればそのまま元の数字に戻る。
    var budgetSpend: Double {
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
            // スクリーンショット用フィクスチャと予算オフ時のクリア。合算を Claude 側に載せ、
            // 二次ソース側は落とす（表示モードが合算なら見た目は同じ）。
            setBudgetSpend(bySource: [CostSourceMode.claudeSourceID: newValue])
        }
    }

    /// ソース 1 つぶんの予算期間内消費額（"claude" または `CostDriver.id`）。
    func budgetSpend(forSource id: String) -> Double { reportedBudgetSpendBySource[id] ?? 0 }

    var claudeBudgetSpend: Double { budgetSpend(forSource: CostSourceMode.claudeSourceID) }

    /// 二次ソース（Claude 以外）の合計。並べて表示の Cursor 側に出す。
    var secondaryBudgetSpend: Double {
        reportedBudgetSpendBySource
            .filter { $0.key != CostSourceMode.claudeSourceID }
            .values.reduce(0, +)
    }

    /// テスト・スクリーンショットからソース別予算を直接入れる。
    func setBudgetSpend(bySource: [String: Double]) {
        if reportedBudgetSpendBySource != bySource { reportedBudgetSpendBySource = bySource }
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
    func menuBarInput(isFollowing: Bool = false) -> MenuBarInput {
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
            cursorUnavailable: !degradedSourceWarnings.isEmpty,
            // 並べて表示は Claude と二次ソース合計の 2 列（この Issue では拡張しない）。
            todayClaude: todayCost(forSource: CostSourceMode.claudeSourceID),
            todayCursor: secondaryTodayCost,
            monthClaude: claudeBudgetSpend,
            monthCursor: secondaryBudgetSpend,
            // ゲージは側ごとに塗り分ける。今日だけしきい値を越えたら今日のゲージだけが変わる。
            todayLevel: dailyBudgetLevel,
            monthLevel: budgetLevel,
            isFollowing: isFollowing)
    }

    /// ソース別の今日の金額（USD）。追従モード（TF-0080）の `RefreshScheduler` が
    /// 「金額が動いたか」を見るためだけの入力で、画面には出さない。
    ///
    /// 表示モード（`costSourceMode`）で合成する前の生の値を返す — 表示から外している
    /// ソースが動いたときも、追従モードには入る。取得が劣化しているソース（TF-0073 の
    /// `CostSnapshot.Health.degraded`）はキーごと落とす。劣化中の 0 は「使っていない」では
    /// なく「取れなかった」なので、復旧した瞬間の 0 → 実額を増加と読むと誤発火する。
    var todayCostBySource: [String: Double] {
        let today = Self.dateString(Date())
        var byID = [CostSourceMode.claudeSourceID: report?.cost(on: today) ?? 0]
        for (id, byDate) in driverDailyByID {
            if case .degraded = driverHealthByID[id] { continue }
            byID[id] = byDate[today] ?? 0
        }
        return byID
    }

    /// 月間予算のレベル（予算オフなら nil）。
    var budgetLevel: BudgetLevel? {
        guard settings.budgetLimit > 0 else { return nil }
        return BudgetMonitor.level(spend: budgetSpend, limit: settings.budgetLimit,
                                   warnPercent: settings.budgetWarnPercent)
    }

    /// 日次予算のレベル（予算オフなら nil）。今日のコストと比較する。
    var dailyBudgetLevel: BudgetLevel? {
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

    /// トランスクリプト走査（バックグラウンド）→ 今日の回数へ反映。retok も並行して実行する。
    func reload() {
        guard !isLoading else { return }
        isLoading = true
        reloadReport()
        reloadBudget()
        // Cursor の価格表を（インストールされていて、当日未取得なら）取り直す。今回の集計には
        // 間に合わなくてもよい — 取れれば次回以降の CursorPricing.cost() から新しい表を使う。
        Task { await CursorPricingService.refreshIfNeeded() }
        rescanTranscripts()
    }

    /// 追従モード（TF-0080）の軽い更新。今日を含む短い窓だけを取り直し、32 日集計
    /// （`reloadBudget`）と表示窓の再解析（`reloadReport`）は回さない。1 分間隔で
    /// python3 のサブプロセスを走らせるので、走査日数は 1 日に絞る。
    ///
    /// 得られた今日のコストは、表示中のレポートに重ねる（レポートごと差し替えると
    /// 推移グラフが 1 日分に痩せてしまう）。重い集計が走り始めたら結果は捨てる。
    func reloadToday() {
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

            // retok が失敗しても（python3 なし等）二次ソースの結果は捨てない（CLAUDE.md ルール 4）。
            let short = try? await retokTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // 表示中のレポートがまだ無いうちは何もしない。1 日ぶんのレポートで埋めると、
            // 期間合計もモデル別も今日だけの値になって誤解を招く（長期集計が届けば埋まる）。
            if let short, let current = self.report {
                self.report = current.merging(daily: short.daily)
            }
            let snapshots = await driverTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // 日別と確度は reloadBudget と同じ扱いにする。追従中に Cursor が取れなくなったら、
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

    /// トランスクリプトを走査して「今日のプロンプト数」を更新する。
    /// 走査元はバックグラウンドスレッドから @MainActor の設定を触らないよう、ここで解決して渡す。
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

    /// retok レポートを再取得する（設定変更や言語変更からも呼べるよう公開）。
    func reloadReport() {
        let period = reportPeriod
        let weekStart = settings.weekStart
        let window = Self.reportWindow(period: period, weekStart: weekStart)
        let days = window.days
        let lang = settings.language.resolved
        // Claude ディレクトリが既定と異なる場合のみ retok に projects を明示指定する。
        let claudeDir = settings.claudeDirectoryURL
        let isDefault = claudeDir.standardizedFileURL.path
            == URL(fileURLWithPath: AppSettings.defaultClaudeDirectory).standardizedFileURL.path
        let projectsOverride = isDefault ? nil : claudeDir.appendingPathComponent("projects")
        reportGeneration += 1
        let generation = reportGeneration
        reportTask?.cancel()
        isReportLoading = true
        // stale-while-revalidate: ディスクの前回結果を先に出し、裏の再解析（数秒）が終わり
        // 次第差し替える。期間切替や再起動直後に画面がスピナーへ戻らない。
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
            // retok（外部プロセス）と二次ソース（SQLite）は互いに独立な I/O なので並行して走らせる。
            // 暦窓の経過日数を --days に渡す（今日までの連続日なのでローリング N 日と同値）。
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

            // retok の成否に関わらず、二次ソースは独立に反映する（失敗しても 0 になるだけ）。
            let snapshots = await driverTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            // 日別とモデル別を同じ取得結果から一括更新する。フォールバック後に古いモデル別だけ
            // 残る状態を作らないため、空の内訳も含めて毎回置き換える。
            self.applyDriverSnapshots(snapshots)

            // セッション別も同じ世代で置き換える（古い会話が残り続けないように）。
            let sessions = await sessionTask
            guard !Task.isCancelled, generation == self.reportGeneration else { return }
            self.applyDriverSessions(sessions)
        }
    }

    /// 予算期間内の消費額を再計算する。表示用レポート（7d/30d 切替）とは独立に、
    /// 暦月の最大長（31 日）を必ずカバーする 32 日分で retok を実行する。
    func reloadBudget() {
        // 集計が不要になった場合も含めて先に世代を進める。そうしないと、実行中の集計が
        // 「0 にした」あとから古い値を書き戻してしまう。
        budgetGeneration += 1
        let generation = budgetGeneration
        budgetTask?.cancel()
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
        budgetTask = Task {
            async let retokTask = RetokService.run(
                days: 32, lang: "en", projectsDir: projectsOverride, provider: "claude"
            )
            async let driverTask = self.fetchDriverSnapshots(from: start, to: today)

            // retok が失敗しても（python3 なし等）二次ソースの結果は捨てない — reloadReport() と
            // 同じく、retok の成否と二次ソースの反映は独立にする（CLAUDE.md ルール 4）。
            let r = try? await retokTask
            // 設定を連続で変えると 32 日集計が並走しうる。古い結果で新しい結果を上書きしない。
            guard !Task.isCancelled, generation == self.budgetGeneration else { return }

            let claudeSpend = r?.daily
                .filter { $0.key >= start }
                .values.reduce(0) { $0 + $1.cost } ?? 0
            let driverSnapshots = await driverTask
            // ソース id 別に持つ。表示モードが「◯◯ のみ」なら、この辞書から該当 id だけを拾う。
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

    // MARK: - 今日

    /// ローカルタイムの YYYY-MM-DD 文字列。集計キーの書式はここが基準。
    nonisolated static func dateString(_ date: Date) -> String {
        LocalDay.string(from: date)
    }

    /// 表示窓の開始日（end を含む days 日間）。retok の --days と同じ数え方。
    nonisolated static func reportWindowStart(days: Int, endingOn end: Date = Date()) -> String {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        return dateString(start)
    }

    /// 暦ベースの表示窓。開始日（YYYY-MM-DD）と、retok に渡す経過日数。
    struct ReportWindow: Equatable, Sendable {
        let start: String
        let days: Int
    }

    /// 今日 / 今週 / 今月 / 今年の開始〜 `end` までを、ローカル暦で数える。
    nonisolated static func reportWindow(
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

    /// 今日の集計（無ければ空の DailyUsage）。
    var today: DailyUsage {
        let key = Self.dateString(Date())
        return daily.first { $0.date == key } ?? DailyUsage(date: key)
    }

    /// 今日のソース 1 つぶんのコスト（"claude" または `CostDriver.id`）。
    func todayCost(forSource id: String) -> Double { todayCostBySource[id] ?? 0 }

    /// 今日の二次ソース合計（Claude を含まない）。並べて表示の Cursor 側に出す。
    var secondaryTodayCost: Double {
        driverDaily[Self.dateString(Date())] ?? 0
    }

    /// 今日の表示コスト。`costSourceMode` が選んだソースだけを合算する。
    /// レポート未取得も 0 とみなす（「不明」は出さず、retok 失敗はエラー表示が伝える）。
    var todayCost: Double {
        #if DEBUG
        if let override = DebugSettings.shared.today { return override }
        #endif
        return Self.displayedSpend(bySource: todayCostBySource, mode: settings.costSourceMode)
    }

    /// ソース表示モードが選んだ id ぶんだけを合算する。
    nonisolated static func displayedSpend(
        bySource: [String: Double], mode: CostSourceMode
    ) -> Double {
        bySource.reduce(0) { $0 + (mode.includes(sourceID: $1.key) ? $1.value : 0) }
    }

}

// MARK: - CostDriver 統合（Cursor 等、Claude/retok に合算する二次ソース）
//
// costDrivers・driverDailyByID（保持型プロパティなので extension には置けない）だけを本体に
// 残し、そこから導出できるものはすべてここにまとめている。新しい CostDriver を足すときは
// costDrivers 配列に 1 行足すだけで、この extension 側は変更不要。

extension UsageStore {
    /// 日別とモデル別を同じ世代の取得結果で置き換える。
    /// internalなのは、フォールバック時に古いモデル別を残さないことをテストするため。
    func applyDriverSnapshots(_ snapshots: [String: CostSnapshot]) {
        driverDailyByID = snapshots.mapValues(\.daily)
        driverModelByID = snapshots.mapValues(\.byModel)
        driverHealthByID = snapshots.mapValues(\.health)
    }

    /// セッション別内訳を置き換える。applyDriverSnapshots と同じく、取得できなかった回は
    /// 空になる（古い会話を残さない）。
    func applyDriverSessions(_ sessions: [String: [CostSnapshot.Session]]) {
        driverSessionsByID = sessions
    }

    /// 劣化した二次ソース 1 件ぶんの注意書き。金額の 0 を「使っていない」と誤読させないため、
    /// UI はこれをそのまま金額の近くに出す。
    struct SourceWarning: Identifiable, Equatable {
        /// driver.id。
        let id: String
        let name: String
        let message: String
        /// サインインし直せば直る劣化で、かつ前面に出せるアプリがあるときだけ入る。
        /// UI はこれがある場合にサインインボタンを添える。
        let signInBundleID: String?
    }

    /// 表示対象になっている二次ソース（表示モードが選んだ id のドライバ）。
    /// 劣化警告と「金額が取れていない」の判定は、この集合だけを見る。
    var displayedDrivers: [any CostDriver] {
        let mode = settings.costSourceMode
        return costDrivers.filter { mode.includes(sourceID: $0.id) }
    }

    private func isDegraded(_ id: String) -> Bool {
        if case .degraded = driverHealthByID[id] { return true }
        return false
    }

    /// 表示している金額が「取れなかった」だけで成り立っているか。
    /// 表示対象の二次ソースが全滅していると、ヒーローの 0 円は情報ではなく誤情報なので、
    /// 金額の代わりに「—」を出すために使う。Claude を含むモードでは扱わない
    /// ——retok の失敗はフッターのエラー行が伝えるため。
    var todayCostUnavailable: Bool {
        guard !settings.costSourceMode.includes(sourceID: CostSourceMode.claudeSourceID)
        else { return false }
        let displayed = displayedDrivers
        guard !displayed.isEmpty else { return false }
        return displayed.allSatisfy { isDegraded($0.id) }
    }

    /// 金額が取れなかった二次ソースの表示名。0 円として並べる代わりに「—」で出すために使う。
    var unknownSourceNames: [String] {
        degradedSourceWarnings.map(\.name)
    }

    /// 取得が劣化している二次ソースの注意書き。表示対象に入っているドライバのぶんだけ出す
    /// ——合計に含めていないソース（「Claude のみ」での Cursor など）の注意書きは、
    /// 見ていない数字の話にしかならない。
    var degradedSourceWarnings: [SourceWarning] {
        displayedDrivers.compactMap { driver in
            guard case .degraded(let reason) = driverHealthByID[driver.id] else { return nil }
            return SourceWarning(
                id: driver.id,
                name: driver.displayName,
                message: reason.message,
                signInBundleID: reason.isRecoverableBySignIn ? driver.signInBundleID : nil)
        }
    }

    /// driver.id → 表示名。グラフの色分け（PopoverView）で使う。costDrivers は注入可能な
    /// インスタンスプロパティなので、これも static ではなくインスタンス側に置く。
    var secondarySourceNames: [String: String] {
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
        return costDrivers.compactMap { driver in
            let cost = driverCost(id: driver.id, on: today)
            return cost > 0 ? (driver.displayName, cost) : nil
        }
    }

    /// costDrivers のうち利用可能なものだけを問い合わせ、id → (日付 → コスト) にまとめる。
    /// reloadReport()/reloadBudget() が別々の期間で呼ぶ共通処理。private でも同一ファイル内の
    /// 本体（reloadReport 等）から呼べる（同一ファイル内の extension は private を共有する）。
    private func fetchDriverSnapshots(from: String, to: String) async -> [String: CostSnapshot] {
        var byID: [String: CostSnapshot] = [:]
        for driver in costDrivers where driver.isAvailable {
            byID[driver.id] = await driver.snapshot(from: from, to: to)
        }
        return byID
    }

    /// セッション別内訳を持つ driver（既定実装は空）から会話を集める。
    /// 空のソースはキーごと落とし、UI 側で「0 件のソース」を気にしなくてよくする。
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
        let mode = settings.costSourceMode
        var claudeByDate: [String: Double] = [:]
        for day in report.dailySorted { claudeByDate[day.date] = day.cost }
        // 二次ソース側は表示窓で絞る。reloadBudget が予算窓（表示窓より広いことがある）の
        // 日別を driverDailyByID に補完するため、絞らないと短い表示窓に予算窓の日が漏れる。
        let from = Self.reportWindowStart(days: report.periodDays)
        let showsClaude = mode.includes(sourceID: CostSourceMode.claudeSourceID)
        var dates = Set<String>()
        if showsClaude { dates.formUnion(claudeByDate.keys) }
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
        guard settings.budgetLimit > 0 else { return nil }
        switch settings.budgetPeriod {
        case .rolling30:
            // チャート側にローリング 30 日窓は無いので、上限の参照線は出さない。
            return nil
        case .calendarMonth:
            // 予算窓と表示窓が初めて一致する組 — 上限の参照線を引ける。
            if reportPeriod == .thisMonth {
                return .referenceLine(limit: settings.budgetLimit)
            }
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
        var bySource = [CostSourceMode.claudeSourceID: report.totals.cost]
        for (id, byDate) in driverDailyByID {
            bySource[id] = byDate.filter { $0.key >= from }.values.reduce(0, +)
        }
        return Self.displayedSpend(bySource: bySource, mode: settings.costSourceMode)
    }

    /// 「モデル別」セクション用の行。ソースフィルタと内訳モードに従う。
    func modelCostRows(for report: RetokReport) -> [ModelCostRow] {
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
            // cursorModelCosts は driverModelByID["cursor"] 専用（Codex はまだモデル別内訳を持たない）
            // ので "Cursor" と実名を出す。複数 driver が持つようになったら見直す。
            rows += cursor.map { ModelCostRow(source: "Cursor", model: $0.0, cost: $0.1) }
            return rows
        }
    }

    // MARK: - 節約のヒント

    /// 「節約のヒント」1 件。retok（Claude）由来と Tokfuel が組み立てた Cursor 由来を
    /// 1 つのリストに並べるため、出どころを添えて持つ。
    struct AdviceItem: Identifiable {
        let source: String
        let advice: RetokReport.Advice
        var id: String { "\(source)|\(advice.key)" }
    }

    /// severity の強さ（小さいほど強い）。並び順にだけ使う。
    /// retok は high / medium / low / info を返し、Cursor 由来は high / info を返す。
    nonisolated static func severityRank(_ severity: String) -> Int {
        switch severity {
        case "high": return 0
        case "medium", "warn": return 1
        case "low": return 2
        default: return 3
        }
    }

    /// 表示する節約のヒント。`costSourceMode` に従って 2 系統を合成し、
    /// severity（high が先）→ ソース名 → キーの順に並べる。
    /// `claudeOnly` では Cursor 由来を、`cursorOnly` では retok 由来を出さない。
    func adviceItems(for report: RetokReport) -> [AdviceItem] {
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
    /// `adviceItems(for:)` が `costSourceMode` でやる。
    var cursorFetchDegraded: Bool {
        if case .degraded = driverHealthByID["cursor"] { return true }
        return false
    }

    /// Cursor 由来のヒントの入力。金額はチャート・期間合計と同じ表示窓で切る
    /// （予算窓の補完分が混ざると、割合の分母が表示と食い違う）。
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

    // MARK: - 高コストのセッション

    /// セッション 1 行。Claude（retok）と二次ソースを同じ形にそろえ、1 本のリストに混ぜる。
    struct TopSessionRow: Identifiable {
        let id: String
        /// ソース名（"Claude" / "Cursor" …）。モデル別内訳と同じく行に添えて区別する。
        let source: String
        let title: String
        let cost: Double
        /// ローカル DB から起こした推定額か。UI は「推定」と添えて、ヒーローの合計とは
        /// 別物であることを示す（Cursor はダッシュボード API の合計と桁がそろわないことがある）。
        let isEstimated: Bool
    }

    /// セクションに出す件数。
    static let topSessionLimit = 3

    /// Claude（retok）と二次ソースの会話をコスト降順でマージした上位数件。
    /// `costSourceMode` に従い、含めないソースの行は作らない（`claudeOnly` なら Cursor 行なし）。
    /// 二次ソースは driver が返した会話だけを並べる —— ローカル走査が空になる環境（#73）では
    /// 単に行が増えず、両ソースとも 0 件ならセクションごと消える。
    func topSessionRows(for report: RetokReport, limit: Int = topSessionLimit) -> [TopSessionRow] {
        let mode = settings.costSourceMode
        var rows: [TopSessionRow] = []
        if mode.includes(sourceID: CostSourceMode.claudeSourceID) {
            rows += report.topSessions.map {
                TopSessionRow(id: "\(Self.claudeSourceLabel)|\($0.session)",
                              source: Self.claudeSourceLabel,
                              title: $0.project, cost: $0.cost, isEstimated: false)
            }
        }
<<<<<<< HEAD
        if mode.includes(sourceID: CostSourceMode.cursorSourceID) {
            let names = secondarySourceNames
            for (id, sessions) in driverSessionsByID {
                let source = names[id] ?? id
                rows += sessions.map {
                    TopSessionRow(id: "\(id)|\($0.id)", source: source,
                                  title: $0.title, cost: $0.cost, isEstimated: true)
                }
=======
        let names = secondarySourceNames
        for (id, sessions) in driverSessionsByID where mode.includes(sourceID: id) {
            let source = names[id] ?? id
            rows += sessions.map {
                TopSessionRow(id: "\(id)|\($0.id)", source: source,
                              title: $0.title, cost: $0.cost, isEstimated: true)
>>>>>>> origin/main
            }
        }
        // 並びが driver の辞書順に揺れないよう、同額は ID で決める。
        let sorted = rows
            .filter { $0.cost > 0 }
            .sorted { $0.cost == $1.cost ? $0.id < $1.id : $0.cost > $1.cost }
        return Array(sorted.prefix(limit))
    }
}
