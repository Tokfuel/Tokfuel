import Foundation
import Combine
import ServiceManagement
import TokfuelCore

/// アプリ全体の設定。UserDefaults に永続化し、変更は @Published で伝播する。
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

    /// Analytics 同意変更時に App が Firebase へ反映するためのコールバック。
    public var onAnalyticsConsentChange: ((Bool) -> Void)?

    private let defaults: UserDefaults

    @Published public var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    /// メニューバーで何を見るか。どう見せるかは menuBarRepresentation 側。
    @Published public var menuBarMetric: MenuBarMetric {
        didSet { persist(menuBarMetric.rawValue, forKey: Keys.menuBarMetric) }
    }
    /// メニューバーの見せ方（金額 / パーセント / リング / リング + 数値 / アイコンのみ）。
    @Published public var menuBarRepresentation: MenuBarRepresentation {
        didSet { persist(menuBarRepresentation.rawValue, forKey: Keys.menuBarRepresentation) }
    }
    /// パーセントとリングが共有する分母。
    @Published public var menuBarPercentBasis: MenuBarPercentBasis {
        didSet { persist(menuBarPercentBasis.rawValue, forKey: Keys.menuBarPercentBasis) }
    }
    /// ゲージの形（リング / タンク）。
    @Published public var menuBarGaugeShape: MenuBarGaugeShape {
        didSet { persist(menuBarGaugeShape.rawValue, forKey: Keys.menuBarGaugeShape) }
    }
    /// リング表示のときに給油機アイコンも並べるか。文字だけの表現では常に出す。
    @Published public var menuBarShowsIcon: Bool {
        didSet { persist(menuBarShowsIcon, forKey: Keys.menuBarShowsIcon) }
    }
    /// メニューバーの値を「消費」ではなく「予算までの残り（上限 − 消費）」で見せる。
    /// 対応する予算が未設定の項目は消費のまま。
    @Published public var menuBarShowsRemaining: Bool {
        didSet { persist(menuBarShowsRemaining, forKey: Keys.menuBarShowsRemaining) }
    }
    /// 使用額が動いている間だけ更新間隔を上げる（TF-0080）。オフなら常に 10 分間隔。
    @Published public var adaptiveRefreshEnabled: Bool {
        didSet { persist(adaptiveRefreshEnabled, forKey: Keys.adaptiveRefreshEnabled) }
    }
    /// 追従モード中にメニューバーのアイコンを明滅させる。オフなら間隔だけが短くなる。
    @Published public var activityAnimationEnabled: Bool {
        didSet { persist(activityAnimationEnabled, forKey: Keys.activityAnimationEnabled) }
    }
    @Published public var language: ReportLanguage {
        didSet { persist(language.rawValue, forKey: Keys.language) }
    }
    /// アプリ UI の外観（ポップオーバー・設定・About）。既定はシステム追従。
    @Published public var appearanceMode: AppearanceMode {
        didSet { persist(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    /// 金額の表示通貨。日本円は Frankfurter API のレート（1 日 1 回取得）で換算する。
    /// 切り替えた瞬間だけ、予算上限額（`budgetLimit`/`dailyBudgetLimit`）を新しい
    /// 通貨のネイティブ単位へ 1 回だけ変換する（以後は時間経過だけでは変わらない）。
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

    /// ポップオーバーとメニューバーでどのコストソースを金額に含めるか。
    @Published public var costSourceMode: CostSourceMode {
        didSet { persist(costSourceMode.rawValue, forKey: Keys.costSourceMode) }
    }
    /// Codex CLI のセッションログがこの Mac にあるか。起動時に 1 度だけ見る。
    /// 無いときは「Codex のみ」を選べないようにする（選んでも常に $0 になるため）。
    public let codexInstalled: Bool

    /// 「コストのソース」ピッカーに出す選択肢。
    public var availableCostSourceModes: [CostSourceMode] {
        CostSourceMode.available(codexInstalled: codexInstalled)
    }
    /// 「モデル別」を 1 一覧にするか、ソースごとに分けるか。
    @Published public var costModelBreakdownMode: CostModelBreakdownMode {
        didSet { persist(costModelBreakdownMode.rawValue, forKey: Keys.costModelBreakdownMode) }
    }

    /// retokのコスト集計とプロンプト数の読み取り元となるClaudeディレクトリ。
    @Published public var claudeDirectory: String {
        didSet { persist(claudeDirectory, forKey: Keys.claudeDirectory) }
    }

    /// 月間（budgetPeriod で定義する期間）のコスト上限。`displayCurrency` の
    /// ネイティブ単位（入力された値をそのまま）で保持する。0 なら月間予算オフ。
    /// USD 値が必要な比較・通知には `budgetLimitUSD` を使う。
    @Published public var budgetLimit: Double {
        didSet { persist(budgetLimit, forKey: Keys.budgetLimit) }
    }
    /// 1 日あたりのコスト上限。`budgetLimit` と同じくネイティブ単位。0 なら日次予算オフ。
    /// 月間とは独立。USD 値が必要なら `dailyBudgetLimitUSD` を使う。
    @Published public var dailyBudgetLimit: Double {
        didSet { persist(dailyBudgetLimit, forKey: Keys.dailyBudgetLimit) }
    }
    /// 予算の集計期間の起点（ローリング 30 日 / 暦月）。
    @Published public var budgetPeriod: BudgetPeriod {
        didSet { persist(budgetPeriod.rawValue, forKey: Keys.budgetPeriod) }
    }
    /// 「今週」の週始まり（土 / 日 / 月）。既定は月曜。
    @Published public var weekStart: WeekStart {
        didSet { persist(weekStart.rawValue, forKey: Keys.weekStart) }
    }
    /// 警告を出すしきい値（上限に対する %）。
    @Published public var budgetWarnPercent: Int {
        didSet { persist(budgetWarnPercent, forKey: Keys.budgetWarnPercent) }
    }
    /// しきい値に達したときの知らせ方（通知 / アラートウィンドウ / 両方）。
    @Published public var budgetAlertStyle: BudgetAlertStyle {
        didSet { persist(budgetAlertStyle.rawValue, forKey: Keys.budgetAlertStyle) }
    }

    /// アプリ自身の UI 利用イベント記録（CU-0013）。ローカル限定・デフォルト有効。
    /// OFF にした事実は意図的に記録しない（オプトアウト後は 1 バイトも書かない）。
    /// 先に defaults へ書くため、続く logChange は enabled=false を読んで自然に落ちる。
    @Published public var eventLogEnabled: Bool {
        didSet { persist(eventLogEnabled, forKey: UsageEventLog.enabledKey) }
    }

    /// Firebase Analytics への匿名利用イベント送信（#22）。デフォルト OFF。
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

    /// 初回の Analytics 同意ダイアログを出し済みか。
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

    /// 既定の Claude ディレクトリ（~/.claude）。
    public static var defaultClaudeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
    }
    /// `~` を展開した Claude ディレクトリの URL。
    public var claudeDirectoryURL: URL {
        URL(fileURLWithPath: (claudeDirectory as NSString).expandingTildeInPath)
    }

    /// 月側の集計に実際に使う期間。予算オフでメニューバー表示のためだけに数える場合は暦月。
    public var effectiveBudgetPeriod: BudgetPeriod {
        budgetLimit > 0 ? budgetPeriod : .calendarMonth
    }

    /// 月間上限の USD 換算値。USD 建ての消費額との比較・通知にはこちらを使う
    /// （`budgetLimit` 自体は `displayCurrency` のネイティブ単位）。
    public var budgetLimitUSD: Double {
        Money.convert(budgetLimit, from: displayCurrency, to: .usd, rate: Money.currentRate(in: defaults))
    }
    /// 日次上限の USD 換算値。`budgetLimitUSD` と同じ理由。
    public var dailyBudgetLimitUSD: Double {
        Money.convert(dailyBudgetLimit, from: displayCurrency, to: .usd, rate: Money.currentRate(in: defaults))
    }

    /// メニューバーが日次平均（過去 30 日）を分母として要求しているか。
    /// 予算が未設定でも 32 日集計を走らせる必要があるかの判断に使う。
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
        // 行い、値の解釈は bool に任せる（as? Bool だと文字列で入った値を取りこぼす）。
        menuBarShowsIcon = defaults.object(forKey: Keys.menuBarShowsIcon) == nil
            ? true : defaults.bool(forKey: Keys.menuBarShowsIcon)
        menuBarShowsRemaining = defaults.bool(forKey: Keys.menuBarShowsRemaining)
        // 追従モードとその明滅はどちらも既定オン。menuBarShowsIcon と同じく、未設定を
        // false と読まないよう存在確認だけ object で行う。
        adaptiveRefreshEnabled = defaults.object(forKey: Keys.adaptiveRefreshEnabled) == nil
            ? true : defaults.bool(forKey: Keys.adaptiveRefreshEnabled)
        activityAnimationEnabled = defaults.object(forKey: Keys.activityAnimationEnabled) == nil
            ? true : defaults.bool(forKey: Keys.activityAnimationEnabled)
        language = ReportLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .auto
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "")
            ?? .system
        displayCurrency = DisplayCurrency(rawValue: defaults.string(forKey: Money.currencyKey) ?? "")
            ?? .usd
        // Codex が消えた Mac で「Codex のみ」が残っていると常に $0 になるので合算へ落とす
        // （保存値は書き換えない。Codex が戻れば選択も戻る）。
        costSourceMode = CostSourceMode.resolved(
            CostSourceMode(rawValue: defaults.string(forKey: Keys.costSourceMode) ?? "") ?? .combined,
            codexInstalled: codexInstalled)
        costModelBreakdownMode = CostModelBreakdownMode(
            rawValue: defaults.string(forKey: Keys.costModelBreakdownMode) ?? "") ?? .combined
        claudeDirectory = defaults.string(forKey: Keys.claudeDirectory) ?? Self.defaultClaudeDirectory
        // 旧バージョンは budgetLimit/dailyBudgetLimit を常に USD で保存していた。USD 以外の
        // 表示通貨のユーザーだけ、一度だけネイティブ単位へ変換する（TF-0116）。self のプロパティは
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
                // rate <= 0（未取得）なら移行フラグを立てず、次回起動で再試行する。
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
    public func syncLoginItem() {
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
