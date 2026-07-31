import Foundation
import Combine
import ServiceManagement

/// retok の集計言語。auto は OS のロケールに従う。
enum ReportLanguage: String, CaseIterable, Identifiable {
    case auto, en, ja
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "自動 (OS 設定)"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
    /// retok に渡す実際の言語コード。
    var resolved: String {
        switch self {
        case .auto: return Locale.current.language.languageCode?.identifier ?? "en"
        case .en: return "en"
        case .ja: return "ja"
        }
    }
}

/// 予算の集計期間の起点。
enum BudgetPeriod: String, CaseIterable, Identifiable {
    case rolling30      // 今日を含む過去 30 日間
    case calendarMonth  // 今月 1 日から今日まで
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rolling30: return "過去 30 日間（今日から遡る）"
        case .calendarMonth: return "今月（1 日から）"
        }
    }
}

/// 「今週」の週始まり。Calendar.weekday（1 = 日曜 … 7 = 土曜）に対応する。
enum WeekStart: String, CaseIterable, Identifiable, Sendable {
    case saturday, sunday, monday
    var id: String { rawValue }
    var label: String {
        switch self {
        case .saturday: return "土曜日"
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        }
    }
    /// `Calendar.firstWeekday` / `component(.weekday)` と同じ番号。
    var weekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .saturday: return 7
        }
    }
}

/// 推移チャートとコストレポートの集計窓（暦ベース。日数は日々変わる）。
enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case today, thisWeek, thisMonth, thisYear
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        case .thisYear: return "今年"
        }
    }

    /// 旧 `reportDays`（ローリング日数）からの移行。未知値は「今月」。
    static func migrated(fromLegacyDays days: Int) -> ReportPeriod {
        switch days {
        case 1: return .today
        case 7: return .thisWeek
        case 365: return .thisYear
        default: return .thisMonth
        }
    }
}

/// アプリ全体の設定。UserDefaults に永続化し、変更は @Published で伝播する。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults: UserDefaults

    @Published var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    /// メニューバーで何を見るか。どう見せるかは menuBarRepresentation 側。
    @Published var menuBarMetric: MenuBarMetric {
        didSet { persist(menuBarMetric.rawValue, forKey: Keys.menuBarMetric) }
    }
    /// メニューバーの見せ方（金額 / パーセント / リング / リング + 数値 / アイコンのみ）。
    @Published var menuBarRepresentation: MenuBarRepresentation {
        didSet { persist(menuBarRepresentation.rawValue, forKey: Keys.menuBarRepresentation) }
    }
    /// パーセントとリングが共有する分母。
    @Published var menuBarPercentBasis: MenuBarPercentBasis {
        didSet { persist(menuBarPercentBasis.rawValue, forKey: Keys.menuBarPercentBasis) }
    }
    /// ゲージの形（リング / タンク）。
    @Published var menuBarGaugeShape: MenuBarGaugeShape {
        didSet { persist(menuBarGaugeShape.rawValue, forKey: Keys.menuBarGaugeShape) }
    }
    /// リング表示のときに給油機アイコンも並べるか。文字だけの表現では常に出す。
    @Published var menuBarShowsIcon: Bool {
        didSet { persist(menuBarShowsIcon, forKey: Keys.menuBarShowsIcon) }
    }
    /// メニューバーの値を「消費」ではなく「予算までの残り（上限 − 消費）」で見せる。
    /// 対応する予算が未設定の項目は消費のまま。
    @Published var menuBarShowsRemaining: Bool {
        didSet { persist(menuBarShowsRemaining, forKey: Keys.menuBarShowsRemaining) }
    }
    @Published var language: ReportLanguage {
        didSet { persist(language.rawValue, forKey: Keys.language) }
    }

    /// 金額の表示通貨。日本円は Frankfurter API のレート（1 日 1 回取得）で換算する。
    @Published var displayCurrency: DisplayCurrency {
        didSet { persist(displayCurrency.rawValue, forKey: Money.currencyKey) }
    }

    /// ポップオーバーとメニューバーで Claude / Cursor のどちらを金額に含めるか。
    @Published var costSourceMode: CostSourceMode {
        didSet { persist(costSourceMode.rawValue, forKey: Keys.costSourceMode) }
    }
    /// 「モデル別」を 1 一覧にするか、ソースごとに分けるか。
    @Published var costModelBreakdownMode: CostModelBreakdownMode {
        didSet { persist(costModelBreakdownMode.rawValue, forKey: Keys.costModelBreakdownMode) }
    }

    /// retokのコスト集計とプロンプト数の読み取り元となるClaudeディレクトリ。
    @Published var claudeDirectory: String {
        didSet { persist(claudeDirectory, forKey: Keys.claudeDirectory) }
    }

    /// 月間（budgetPeriod で定義する期間）のコスト上限 (USD)。0 なら月間予算オフ。
    @Published var budgetLimit: Double {
        didSet { persist(budgetLimit, forKey: Keys.budgetLimit) }
    }
    /// 1 日あたりのコスト上限 (USD)。0 なら日次予算オフ。月間とは独立。
    @Published var dailyBudgetLimit: Double {
        didSet { persist(dailyBudgetLimit, forKey: Keys.dailyBudgetLimit) }
    }
    /// 予算の集計期間の起点（ローリング 30 日 / 暦月）。
    @Published var budgetPeriod: BudgetPeriod {
        didSet { persist(budgetPeriod.rawValue, forKey: Keys.budgetPeriod) }
    }
    /// 「今週」の週始まり（土 / 日 / 月）。既定は月曜。
    @Published var weekStart: WeekStart {
        didSet { persist(weekStart.rawValue, forKey: Keys.weekStart) }
    }
    /// 警告を出すしきい値（上限に対する %）。
    @Published var budgetWarnPercent: Int {
        didSet { persist(budgetWarnPercent, forKey: Keys.budgetWarnPercent) }
    }

    /// アプリ自身の UI 利用イベント記録（CU-0013）。ローカル限定・デフォルト有効。
    /// OFF にした事実は意図的に記録しない（オプトアウト後は 1 バイトも書かない）。
    /// 先に defaults へ書くため、続く logChange は enabled=false を読んで自然に落ちる。
    @Published var eventLogEnabled: Bool {
        didSet { persist(eventLogEnabled, forKey: UsageEventLog.enabledKey) }
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        /// 指標 × 表現に分解する前の単一設定。移行のために読むだけで、もう書かない。
        static let legacyMenuBarDisplay = "menuBarDisplay"
        static let menuBarMetric = "menuBarMetric"
        static let menuBarRepresentation = "menuBarRepresentation"
        static let menuBarPercentBasis = "menuBarPercentBasis"
        static let menuBarGaugeShape = "menuBarGaugeShape"
        static let menuBarShowsIcon = "menuBarShowsIcon"
        static let menuBarShowsRemaining = "menuBarShowsRemaining"
        static let language = "language"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let claudeDirectory = "claudeDirectory"
        static let budgetLimit = "budgetLimit"
        static let dailyBudgetLimit = "dailyBudgetLimit"
        static let budgetPeriod = "budgetPeriod"
        static let weekStart = "weekStart"
        static let budgetWarnPercent = "budgetWarnPercent"
        static let costSourceMode = "costSourceMode"
        static let costModelBreakdownMode = "costModelBreakdownMode"
    }

    /// 既定の Claude ディレクトリ（~/.claude）。
    static var defaultClaudeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
    }
    /// `~` を展開した Claude ディレクトリの URL。
    var claudeDirectoryURL: URL {
        URL(fileURLWithPath: (claudeDirectory as NSString).expandingTildeInPath)
    }

    /// 月側の集計に実際に使う期間。予算オフでメニューバー表示のためだけに数える場合は暦月。
    var effectiveBudgetPeriod: BudgetPeriod {
        budgetLimit > 0 ? budgetPeriod : .calendarMonth
    }

    /// メニューバーが日次平均（過去 30 日）を分母として要求しているか。
    /// 予算が未設定でも 32 日集計を走らせる必要があるかの判断に使う。
    var menuBarNeedsDailyAverage: Bool {
        menuBarRepresentation.needsBasis
            && menuBarPercentBasis == .dailyAverage30
            && menuBarMetric.supportsRatio
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 初回起動時は「入れるだけで常駐」を実現するため、ログイン起動を既定 ON にする。
        let firstLaunch = !defaults.bool(forKey: Keys.hasLaunchedBefore)
        if firstLaunch {
            defaults.set(true, forKey: Keys.hasLaunchedBefore)
            defaults.set(true, forKey: Keys.launchAtLogin)
        }
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        // 新キーが未設定なら旧 menuBarDisplay を読み替える。旧キーは消さないので、
        // 古いバージョンに戻しても設定はそのまま残る。
        let legacy = MenuBarReadout.migrated(legacy: defaults.string(forKey: Keys.legacyMenuBarDisplay))
        menuBarMetric = MenuBarMetric(rawValue: defaults.string(forKey: Keys.menuBarMetric) ?? "")
            ?? legacy?.metric ?? .today
        menuBarRepresentation = MenuBarRepresentation(
            rawValue: defaults.string(forKey: Keys.menuBarRepresentation) ?? "")
            ?? legacy?.representation ?? .amount
        menuBarPercentBasis = MenuBarPercentBasis(
            rawValue: defaults.string(forKey: Keys.menuBarPercentBasis) ?? "") ?? .budgetLimit
        menuBarGaugeShape = MenuBarGaugeShape(
            rawValue: defaults.string(forKey: Keys.menuBarGaugeShape) ?? "") ?? .ring
        // 既定はアイコンあり。bool(forKey:) は未設定を false と読むので、存在確認だけ object で
        // 行い、値の解釈は bool に任せる（as? Bool だと文字列で入った値を取りこぼす）。
        menuBarShowsIcon = defaults.object(forKey: Keys.menuBarShowsIcon) == nil
            ? true : defaults.bool(forKey: Keys.menuBarShowsIcon)
        menuBarShowsRemaining = defaults.bool(forKey: Keys.menuBarShowsRemaining)
        language = ReportLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .auto
        displayCurrency = DisplayCurrency(rawValue: defaults.string(forKey: Money.currencyKey) ?? "")
            ?? .usd
        costSourceMode = CostSourceMode(rawValue: defaults.string(forKey: Keys.costSourceMode) ?? "")
            ?? .combined
        costModelBreakdownMode = CostModelBreakdownMode(
            rawValue: defaults.string(forKey: Keys.costModelBreakdownMode) ?? "") ?? .combined
        claudeDirectory = defaults.string(forKey: Keys.claudeDirectory) ?? Self.defaultClaudeDirectory
        budgetLimit = defaults.double(forKey: Keys.budgetLimit)
        dailyBudgetLimit = defaults.double(forKey: Keys.dailyBudgetLimit)
        budgetPeriod = BudgetPeriod(rawValue: defaults.string(forKey: Keys.budgetPeriod) ?? "")
            ?? .calendarMonth
        weekStart = WeekStart(rawValue: defaults.string(forKey: Keys.weekStart) ?? "") ?? .monday
        let warn = defaults.integer(forKey: Keys.budgetWarnPercent)
        budgetWarnPercent = (50...99).contains(warn) ? warn : 80
        eventLogEnabled = UsageEventLog.isEnabled(in: defaults)
    }

    /// 設定を保存し、変更を利用イベントとして記録する（値そのものは書かない）。
    /// 新しい設定はこのヘルパー経由にすること（記録漏れを防ぐ）。
    private func persist(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        logChange(key)
    }

    /// 設定変更を利用イベントとして記録する（値そのものは書かない）。
    private func logChange(_ key: String) {
        UsageEventLog.shared.log(.settingChange, meta: ["key": key])
    }

    /// 起動時に、保存済み設定と実際のログイン項目登録状態を突き合わせる。
    func syncLoginItem() {
        applyLaunchAtLogin()
    }

    /// ログイン項目の登録／解除を実際の設定値に合わせる。
    /// .app として起動している場合のみ有効（`swift run` では no-op）。
    private func applyLaunchAtLogin() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // 登録失敗は致命的ではないため握りつぶす（署名前ビルドなどで起こりうる）。
        }
    }
}
