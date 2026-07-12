import Foundation
import Combine
import ServiceManagement

/// メニューバーに常時表示する内容。
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case cost, prompts, iconOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cost: return "今日のコスト"
        case .prompts: return "今日のプロンプト数"
        case .iconOnly: return "アイコンのみ"
        }
    }
}

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

/// アプリ全体の設定。UserDefaults に永続化し、変更は @Published で伝播する。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var launchAtLogin: Bool { didSet { applyLaunchAtLogin() } }
    @Published var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: Keys.menuBarDisplay) }
    }
    @Published var defaultPeriodDays: Int {
        didSet { defaults.set(defaultPeriodDays, forKey: Keys.defaultPeriodDays) }
    }
    @Published var language: ReportLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    /// tool 集計元（transcripts）と skill（global/plugin）の読み取り元となる Claude ディレクトリ。
    @Published var claudeDirectory: String {
        didSet { defaults.set(claudeDirectory, forKey: Keys.claudeDirectory) }
    }
    /// プロジェクト単位の skill (`.claude/skills`) を探すリポジトリのルート。
    @Published var repositoryRoot: String {
        didSet { defaults.set(repositoryRoot, forKey: Keys.repositoryRoot) }
    }

    /// 期間あたりのコスト上限 (USD)。0 なら予算機能オフ。
    @Published var budgetLimit: Double {
        didSet { defaults.set(budgetLimit, forKey: Keys.budgetLimit) }
    }
    /// 予算の集計期間の起点（ローリング 30 日 / 暦月）。
    @Published var budgetPeriod: BudgetPeriod {
        didSet { defaults.set(budgetPeriod.rawValue, forKey: Keys.budgetPeriod) }
    }
    /// 警告を出すしきい値（上限に対する %）。
    @Published var budgetWarnPercent: Int {
        didSet { defaults.set(budgetWarnPercent, forKey: Keys.budgetWarnPercent) }
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let menuBarDisplay = "menuBarDisplay"
        static let defaultPeriodDays = "defaultPeriodDays"
        static let language = "language"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let claudeDirectory = "claudeDirectory"
        static let repositoryRoot = "repositoryRoot"
        static let budgetLimit = "budgetLimit"
        static let budgetPeriod = "budgetPeriod"
        static let budgetWarnPercent = "budgetWarnPercent"
    }

    /// 既定の Claude ディレクトリ（~/.claude）。
    static var defaultClaudeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
    }
    /// 既定のリポジトリルート（~/ghq）。
    static var defaultRepositoryRoot: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("ghq").path
    }

    /// `~` を展開した Claude ディレクトリの URL。
    var claudeDirectoryURL: URL {
        URL(fileURLWithPath: (claudeDirectory as NSString).expandingTildeInPath)
    }
    /// `~` を展開したリポジトリルートの URL。
    var repositoryRootURL: URL {
        URL(fileURLWithPath: (repositoryRoot as NSString).expandingTildeInPath)
    }

    private init() {
        // 初回起動時は「入れるだけで常駐」を実現するため、ログイン起動を既定 ON にする。
        let firstLaunch = !defaults.bool(forKey: Keys.hasLaunchedBefore)
        if firstLaunch {
            defaults.set(true, forKey: Keys.hasLaunchedBefore)
            defaults.set(true, forKey: Keys.launchAtLogin)
        }
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        menuBarDisplay = MenuBarDisplay(rawValue: defaults.string(forKey: Keys.menuBarDisplay) ?? "")
            ?? .cost
        let days = defaults.integer(forKey: Keys.defaultPeriodDays)
        defaultPeriodDays = days == 7 || days == 30 ? days : 30
        language = ReportLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .auto
        claudeDirectory = defaults.string(forKey: Keys.claudeDirectory) ?? Self.defaultClaudeDirectory
        repositoryRoot = defaults.string(forKey: Keys.repositoryRoot) ?? Self.defaultRepositoryRoot
        budgetLimit = defaults.double(forKey: Keys.budgetLimit)
        budgetPeriod = BudgetPeriod(rawValue: defaults.string(forKey: Keys.budgetPeriod) ?? "")
            ?? .calendarMonth
        let warn = defaults.integer(forKey: Keys.budgetWarnPercent)
        budgetWarnPercent = (50...99).contains(warn) ? warn : 80
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
