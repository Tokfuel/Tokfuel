import Foundation
import Combine
import ServiceManagement
import TokfuelCore

@MainActor
public final class AppSettings: ObservableObject {
    private static var _shared: AppSettings?
    public static func bootstrap(codexInstalled: Bool) {
        guard _shared == nil else { return }
        _shared = AppSettings(codexInstalled: codexInstalled)
    }

    public static var shared: AppSettings {
        #if DEBUG
        if _shared == nil {
            bootstrap(codexInstalled: false)
        }
        #else
        precondition(_shared != nil, "AppSettings.bootstrap(codexInstalled:) を先に呼ぶ")
        #endif
        return _shared!
    }

    public var onAnalyticsConsentChange: ((Bool) -> Void)?

    private let defaults: UserDefaults

    @Published public var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    @Published public var menuBarMetric: MenuBarMetric {
        didSet { persist(menuBarMetric.rawValue, forKey: Keys.menuBarMetric) }
    }
    @Published public var menuBarRepresentation: MenuBarRepresentation {
        didSet { persist(menuBarRepresentation.rawValue, forKey: Keys.menuBarRepresentation) }
    }
    @Published public var menuBarPercentBasis: MenuBarPercentBasis {
        didSet { persist(menuBarPercentBasis.rawValue, forKey: Keys.menuBarPercentBasis) }
    }
    @Published public var menuBarGaugeShape: MenuBarGaugeShape {
        didSet { persist(menuBarGaugeShape.rawValue, forKey: Keys.menuBarGaugeShape) }
    }
    @Published public var menuBarShowsIcon: Bool {
        didSet { persist(menuBarShowsIcon, forKey: Keys.menuBarShowsIcon) }
    }
    @Published public var menuBarShowsRemaining: Bool {
        didSet { persist(menuBarShowsRemaining, forKey: Keys.menuBarShowsRemaining) }
    }
    /// 使用額が動いている間だけ更新間隔を上げる。オフなら常に 10 分間隔。
    @Published public var adaptiveRefreshEnabled: Bool {
        didSet { persist(adaptiveRefreshEnabled, forKey: Keys.adaptiveRefreshEnabled) }
    }
    @Published public var activityAnimationEnabled: Bool {
        didSet { persist(activityAnimationEnabled, forKey: Keys.activityAnimationEnabled) }
    }
    @Published public var language: ReportLanguage {
        didSet { persist(language.rawValue, forKey: Keys.language) }
    }
    @Published public var appearanceMode: AppearanceMode {
        didSet { persist(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    /// レート未取得（`rate <= 0`）のときは変換すると誤った値を確定保存しかねないため、
    /// 何もせず据え置く（次に切り替えたときにレートが揃っていれば変換される）。
    @Published public var displayCurrency: DisplayCurrency {
        didSet {
            persist(displayCurrency.rawValue, forKey: Money.currencyKey)
            guard oldValue != displayCurrency else { return }
            let rate = Money.currentRate(in: defaults)
            guard rate > 0 else { return }
            budgetLimit = Money.convert(budgetLimit, from: oldValue, to: displayCurrency, rate: rate)
            dailyBudgetLimit = Money.convert(dailyBudgetLimit, from: oldValue, to: displayCurrency, rate: rate)
        }
    }

    @Published public var costSourceMode: CostSourceMode {
        didSet { persist(costSourceMode.rawValue, forKey: Keys.costSourceMode) }
    }
    public let codexInstalled: Bool

    public var availableCostSourceModes: [CostSourceMode] {
        CostSourceMode.available(codexInstalled: codexInstalled)
    }
    @Published public var costModelBreakdownMode: CostModelBreakdownMode {
        didSet { persist(costModelBreakdownMode.rawValue, forKey: Keys.costModelBreakdownMode) }
    }

    @Published public var claudeDirectory: String {
        didSet { persist(claudeDirectory, forKey: Keys.claudeDirectory) }
    }

    @Published public var budgetLimit: Double {
        didSet { persist(budgetLimit, forKey: Keys.budgetLimit) }
    }
    @Published public var dailyBudgetLimit: Double {
        didSet { persist(dailyBudgetLimit, forKey: Keys.dailyBudgetLimit) }
    }
    @Published public var budgetPeriod: BudgetPeriod {
        didSet { persist(budgetPeriod.rawValue, forKey: Keys.budgetPeriod) }
    }
    @Published public var weekStart: WeekStart {
        didSet { persist(weekStart.rawValue, forKey: Keys.weekStart) }
    }
    @Published public var budgetWarnPercent: Int {
        didSet { persist(budgetWarnPercent, forKey: Keys.budgetWarnPercent) }
    }
    @Published public var budgetAlertStyle: BudgetAlertStyle {
        didSet { persist(budgetAlertStyle.rawValue, forKey: Keys.budgetAlertStyle) }
    }

    /// OFF にした事実は意図的に記録しない（オプトアウト後は 1 バイトも書かない）。
    /// 先に defaults へ書くため、続く logChange は enabled=false を読んで自然に落ちる。
    @Published public var eventLogEnabled: Bool {
        didSet { persist(eventLogEnabled, forKey: UsageEventLog.enabledKey) }
    }

    /// 配布ビルド以外ではトグル値に関わらず送信しない（`RemoteDiagnosticsPolicy`）。
    @Published public var analyticsConsent: Bool {
        didSet {
            defaults.set(analyticsConsent, forKey: Keys.analyticsConsent)
            defaults.set(true, forKey: Keys.analyticsConsentAnswered)
            onAnalyticsConsentChange?(analyticsConsent)
            if analyticsConsent {
                logChange(Keys.analyticsConsent)
            }
        }
    }

    public var analyticsConsentAnswered: Bool {
        defaults.bool(forKey: Keys.analyticsConsentAnswered)
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
        static let adaptiveRefreshEnabled = "adaptiveRefreshEnabled"
        static let activityAnimationEnabled = "activityAnimationEnabled"
        static let language = "language"
        static let appearanceMode = "appearanceMode"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let claudeDirectory = "claudeDirectory"
        static let budgetLimit = "budgetLimit"
        static let dailyBudgetLimit = "dailyBudgetLimit"
        static let budgetLimitCurrencyMigrated = "budgetLimitCurrencyMigrated"
        static let budgetPeriod = "budgetPeriod"
        static let weekStart = "weekStart"
        static let budgetWarnPercent = "budgetWarnPercent"
        static let budgetAlertStyle = "budgetAlertStyle"
        static let costSourceMode = "costSourceMode"
        static let costModelBreakdownMode = "costModelBreakdownMode"
        static let analyticsConsent = "analyticsConsent"
        static let analyticsConsentAnswered = "analyticsConsentAnswered"
    }

    public static var defaultClaudeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
    }
    public var claudeDirectoryURL: URL {
        URL(fileURLWithPath: (claudeDirectory as NSString).expandingTildeInPath)
    }

    public var effectiveBudgetPeriod: BudgetPeriod {
        budgetLimit > 0 ? budgetPeriod : .calendarMonth
    }

    public var budgetLimitUSD: Double {
        Money.convert(budgetLimit, from: displayCurrency, to: .usd, rate: Money.currentRate(in: defaults))
    }
    public var dailyBudgetLimitUSD: Double {
        Money.convert(dailyBudgetLimit, from: displayCurrency, to: .usd, rate: Money.currentRate(in: defaults))
    }

    public var menuBarNeedsDailyAverage: Bool {
        menuBarRepresentation.needsBasis
            && menuBarPercentBasis == .dailyAverage30
            && menuBarMetric.supportsRatio
    }

    public init(defaults: UserDefaults = .standard,
                codexInstalled: Bool = false) {
        self.defaults = defaults
        self.codexInstalled = codexInstalled
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
        // 行い、値の解釈は bool に任せる。
        menuBarShowsIcon = defaults.object(forKey: Keys.menuBarShowsIcon) == nil
            ? true : defaults.bool(forKey: Keys.menuBarShowsIcon)
        menuBarShowsRemaining = defaults.bool(forKey: Keys.menuBarShowsRemaining)
        adaptiveRefreshEnabled = defaults.object(forKey: Keys.adaptiveRefreshEnabled) == nil
            ? true : defaults.bool(forKey: Keys.adaptiveRefreshEnabled)
        activityAnimationEnabled = defaults.object(forKey: Keys.activityAnimationEnabled) == nil
            ? true : defaults.bool(forKey: Keys.activityAnimationEnabled)
        language = ReportLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .auto
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "")
            ?? .system
        displayCurrency = DisplayCurrency(rawValue: defaults.string(forKey: Money.currencyKey) ?? "")
            ?? .usd
        costSourceMode = CostSourceMode.resolved(
            CostSourceMode(rawValue: defaults.string(forKey: Keys.costSourceMode) ?? "") ?? .combined,
            codexInstalled: codexInstalled)
        costModelBreakdownMode = CostModelBreakdownMode(
            rawValue: defaults.string(forKey: Keys.costModelBreakdownMode) ?? "") ?? .combined
        claudeDirectory = defaults.string(forKey: Keys.claudeDirectory) ?? Self.defaultClaudeDirectory
        // 旧バージョンは budgetLimit/dailyBudgetLimit を常に USD で保存していた。USD 以外の
        // 表示通貨のユーザーだけ、一度だけネイティブ単位へ変換する。self のプロパティは
        // 全部そろうまで読めない（2 段階初期化）ので、ここではローカル変数だけで完結させる。
        var migratedBudgetLimit = defaults.double(forKey: Keys.budgetLimit)
        var migratedDailyBudgetLimit = defaults.double(forKey: Keys.dailyBudgetLimit)
        if !defaults.bool(forKey: Keys.budgetLimitCurrencyMigrated) {
            let currency = DisplayCurrency(rawValue: defaults.string(forKey: Money.currencyKey) ?? "")
                ?? .usd
            if currency != .usd, migratedBudgetLimit > 0 || migratedDailyBudgetLimit > 0 {
                let rate = Money.currentRate(in: defaults)
                if rate > 0 {
                    migratedBudgetLimit = Money.convert(migratedBudgetLimit, from: .usd, to: currency, rate: rate)
                    migratedDailyBudgetLimit = Money.convert(
                        migratedDailyBudgetLimit, from: .usd, to: currency, rate: rate)
                    defaults.set(migratedBudgetLimit, forKey: Keys.budgetLimit)
                    defaults.set(migratedDailyBudgetLimit, forKey: Keys.dailyBudgetLimit)
                    defaults.set(true, forKey: Keys.budgetLimitCurrencyMigrated)
                }
            } else {
                defaults.set(true, forKey: Keys.budgetLimitCurrencyMigrated)
            }
        }
        budgetLimit = migratedBudgetLimit
        dailyBudgetLimit = migratedDailyBudgetLimit
        budgetPeriod = BudgetPeriod(rawValue: defaults.string(forKey: Keys.budgetPeriod) ?? "")
            ?? .calendarMonth
        weekStart = WeekStart(rawValue: defaults.string(forKey: Keys.weekStart) ?? "") ?? .monday
        let warn = defaults.integer(forKey: Keys.budgetWarnPercent)
        budgetWarnPercent = (50...99).contains(warn) ? warn : 80
        budgetAlertStyle = BudgetAlertStyle(
            rawValue: defaults.string(forKey: Keys.budgetAlertStyle) ?? "") ?? .notification
        eventLogEnabled = UsageEventLog.isEnabled(in: defaults)
        analyticsConsent = defaults.bool(forKey: Keys.analyticsConsent)
    }

    private func persist(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        logChange(key)
    }

    private func logChange(_ key: String) {
        UsageEventLog.shared.log(.settingChange, meta: ["key": key])
    }

    public func syncLoginItem() {
        applyLaunchAtLogin()
    }

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
        }
    }
}
