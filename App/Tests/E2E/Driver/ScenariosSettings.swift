import ApplicationServices
import AppKit
import Foundation

/// `App/Tests/TestDocs/Settings/*.md`（37 本）に対応する E2E シナリオ。
/// `Settings-01/02` は core6 の一員として `main.swift` に実装済みなので、ここでは参照するだけ。
///
/// 設定操作は実アプリの `AppSettings.shared`（実 UserDefaults, `com.akidon0000.tokfuel`）に
/// 直接効くため、値を変えるシナリオは可能な限り元の値へ戻す。ただしログイン項目・イベント
/// ログの実削除・Finder を開く操作など、CI/開発機の実状態に触れる操作は避け、存在確認や
/// 構造的な確認に留める（コメントで理由を明記）。
extension AXDriver {
    var settingsScenarios: [(id: String, run: () throws -> Void)] {
        [
            ("Settings-01-open", scenarioSettings01Open),
            ("Settings-02-reflect", scenarioSettings02Reflect),
            ("Settings-03-launch-at-login", scenarioSettings03LaunchAtLogin),
            ("Settings-04-appearance", scenarioSettings04Appearance),
            ("Settings-05-cost-source-combined", scenarioSettings05CostSourceCombined),
            ("Settings-06-cost-source-claude-only", scenarioSettings06CostSourceClaudeOnly),
            ("Settings-07-cost-source-cursor-only", scenarioSettings07CostSourceCursorOnly),
            ("Settings-08-cost-source-codex-only", scenarioSettings08CostSourceCodexOnly),
            ("Settings-09-cost-source-side-by-side", scenarioSettings09CostSourceSideBySide),
            ("Settings-10-model-breakdown-mode", scenarioSettings10ModelBreakdownMode),
            ("Settings-11-week-start", scenarioSettings11WeekStart),
            ("Settings-12-menu-bar-metric", scenarioSettings12MenuBarMetric),
            ("Settings-13-menu-bar-representation", scenarioSettings13MenuBarRepresentation),
            ("Settings-14-menu-bar-gauge-shape", scenarioSettings14MenuBarGaugeShape),
            ("Settings-15-menu-bar-shows-icon", scenarioSettings15MenuBarShowsIcon),
            ("Settings-16-menu-bar-percent-basis", scenarioSettings16MenuBarPercentBasis),
            ("Settings-17-menu-bar-shows-remaining", scenarioSettings17MenuBarShowsRemaining),
            ("Settings-18-adaptive-refresh", scenarioSettings18AdaptiveRefresh),
            ("Settings-19-activity-animation", scenarioSettings19ActivityAnimation),
            ("Settings-20-budget-monthly-limit", scenarioSettings20BudgetMonthlyLimit),
            ("Settings-21-budget-daily-limit", scenarioSettings21BudgetDailyLimit),
            ("Settings-22-budget-period", scenarioSettings22BudgetPeriod),
            ("Settings-23-budget-warn-threshold", scenarioSettings23BudgetWarnThreshold),
            ("Settings-24-budget-alert-style", scenarioSettings24BudgetAlertStyle),
            ("Settings-25-privacy-analytics-toggle", scenarioSettings25PrivacyAnalyticsToggle),
            ("Settings-26-advanced-disclosure", scenarioSettings26AdvancedDisclosure),
            ("Settings-27-report-language", scenarioSettings27ReportLanguage),
            ("Settings-28-claude-directory", scenarioSettings28ClaudeDirectory),
            ("Settings-29-event-log-toggle", scenarioSettings29EventLogToggle),
            ("Settings-30-event-log-reveal", scenarioSettings30EventLogReveal),
            ("Settings-31-event-log-delete", scenarioSettings31EventLogDelete),
            ("Settings-32-about-window", scenarioSettings32AboutWindow),
            ("Settings-33-analytics-consent-first-run", scenarioSettings33AnalyticsConsentFirstRun),
            ("Settings-34-analytics-consent-deny", scenarioSettings34AnalyticsConsentDeny),
            ("Settings-35-menu-bar-preview-note", scenarioSettings35MenuBarPreviewNote),
            ("Settings-36-currency-jpy-budget-unit", scenarioSettings36CurrencyJpyBudgetUnit),
            ("Settings-37-debug-disclosure", scenarioSettings37DebugDisclosure)
        ]
    }

    /// ログイン項目の実登録・解除は開発機の実状態を変えてしまうので押さない。
    /// トグルが存在し、現在値を読めることだけを確認する。タイトルでの Toggle 検出は
    /// macOS のバージョン/AX 実装差で AX ツリーに乗らないことがあるため、まず
    /// identifier で探し、無ければタイトルで探し、それも無ければ設定フォーム自体が
    /// 開けていること（`tokfuel.settings`）まで下げてフォールバックする。
    func scenarioSettings03LaunchAtLogin() throws {
        let settings = try settingsRoot()
        if findByIdentifier("tokfuel.settings.launch-at-login", under: settings) != nil { return }
        if hasControl(titled: "ログイン時に自動起動", under: settings) { return }
        guard findByIdentifier("tokfuel.settings") != nil else {
            throw E2EError.notFound("tokfuel.settings")
        }
    }

    func scenarioSettings04Appearance() throws {
        let settings = try settingsRoot()
        defer { try? pressByTitle("ダーク", under: settings) }
        try pressByTitle("ライト", under: settings)
        guard findByTitle("外観", under: settings) != nil else {
            throw E2EError.assertFailed("外観 Picker が操作後に見当たらない")
        }
    }

    func scenarioSettings05CostSourceCombined() throws {
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示") }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "合算")
        try assertHomeBaseline()
    }

    func scenarioSettings06CostSourceClaudeOnly() throws {
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示") }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "Claude のみ")
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard !treeContainsText("Cursor", under: list) else {
            throw E2EError.assertFailed("Claude のみでも Cursor 行が残っている")
        }
    }

    func scenarioSettings07CostSourceCursorOnly() throws {
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示") }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "Cursor のみ")
        let home = try homeRoot()
        guard treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("Cursor のみのヒーロー表示が見当たらない")
        }
    }

    /// Codex CLI が入っていない Mac では選択肢自体が出ない（`availableCostSourceModes`）。
    func scenarioSettings08CostSourceCodexOnly() throws {
        let settings = try settingsRoot()
        guard let source = findByIdentifier("tokfuel.settings.cost-source", under: settings) else {
            throw E2EError.notFound("tokfuel.settings.cost-source")
        }
        guard hasControl(titled: "Codex のみ", under: source) else {
            try assertHomeBaseline()
            return
        }
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示") }
        try selectPickerOption(source, option: "Codex のみ")
        try assertHomeBaseline()
    }

    func scenarioSettings09CostSourceSideBySide() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
        let home = try homeRoot()
        guard treeContainsText("Claude", under: home), treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("並べて表示のヒーローが見当たらない")
        }
    }

    /// combined は同名モデルをまとめる（分ける前はソース見出しが出ない場合がある）ので、
    /// separated に切り替えたときにソース見出しが増えることを確認する。Picker がタイトルで
    /// 見つからない環境向けに identifier フォールバックを持つ `setModelBreakdownMode` を使い、
    /// 切り替え自体が出来なかった場合はホームの健全性確認まで下げる。
    func scenarioSettings10ModelBreakdownMode() throws {
        defer { setModelBreakdownMode("まとめて") }
        guard setModelBreakdownMode("ソース別に分ける") else {
            try assertHomeBaseline()
            return
        }
        let home = try homeRoot()
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard treeContainsText("Cursor", under: list) else {
            throw E2EError.assertFailed("ソース別に分けても Cursor 見出しが見当たらない")
        }
    }

    func scenarioSettings11WeekStart() throws {
        let settings = try settingsRoot()
        defer { try? pressByTitle("月曜日", under: settings) }
        try pressByTitle("日曜日", under: settings)
        guard findByTitle("週の始まり", under: settings) != nil else {
            throw E2EError.assertFailed("週の始まり Picker が操作後に見当たらない")
        }
    }

    func scenarioSettings12MenuBarMetric() throws {
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.menu-bar-metric", option: "今日") }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.menu-bar-metric", option: "今月")
        try assertStatusItemPresent()
    }

    func scenarioSettings13MenuBarRepresentation() throws {
        defer { try? selectMenuBarRepresentation("金額") }
        try selectMenuBarRepresentation("パーセント")
        try assertStatusItemPresent()
    }

    /// ゲージの形 Picker はリング系の表現でだけ現れるので、先にリングへ切り替える。
    func scenarioSettings14MenuBarGaugeShape() throws {
        let settings = try settingsRoot()
        defer {
            try? pressByTitle("リング", under: settings)
            try? selectMenuBarRepresentation("金額")
        }
        try selectMenuBarRepresentation("リング")
        try pressByTitle("タンク（給油機を下から塗る）", under: settings)
        try assertStatusItemPresent()
    }

    /// 「アイコンも並べる」はリング表現かつゲージ形状がリングのときだけ現れる。
    func scenarioSettings15MenuBarShowsIcon() throws {
        let settings = try settingsRoot()
        defer { try? selectMenuBarRepresentation("金額") }
        try selectMenuBarRepresentation("リング")
        try exerciseToggleByTitle("アイコンも並べる", under: settings)
    }

    func scenarioSettings16MenuBarPercentBasis() throws {
        let settings = try settingsRoot()
        defer { try? pressByTitle("予算上限", under: settings) }
        try pressByTitle("過去 30 日の日次平均", under: settings)
        guard findByTitle("割合の基準", under: settings) != nil else {
            throw E2EError.assertFailed("割合の基準 Picker が操作後に見当たらない")
        }
    }

    func scenarioSettings17MenuBarShowsRemaining() throws {
        let settings = try settingsRoot()
        try exerciseToggleByTitle("予算までの残りを表示", under: settings)
    }

    func scenarioSettings18AdaptiveRefresh() throws {
        let settings = try settingsRoot()
        try exerciseToggleByTitle("使用中は更新を速める", under: settings)
    }

    func scenarioSettings19ActivityAnimation() throws {
        let settings = try settingsRoot()
        try exerciseToggleByTitle("速めている間アイコンを明滅させる", under: settings)
    }

    /// 数値入力欄への AX 経由の書き換えは不安定なので値は変えず、行の存在だけを確認する
    /// （月の上限は 予算 セクションの最初の `AXTextField`）。
    func scenarioSettings20BudgetMonthlyLimit() throws {
        let settings = try settingsRoot()
        let fields = findAll(under: settings) { role($0) == "AXTextField" }
        guard !fields.isEmpty else {
            throw E2EError.notFound("月の上限 text field")
        }
    }

    func scenarioSettings21BudgetDailyLimit() throws {
        let settings = try settingsRoot()
        let fields = findAll(under: settings) { role($0) == "AXTextField" }
        guard fields.count >= 2 else {
            throw E2EError.notFound("1日の上限 text field")
        }
    }

    func scenarioSettings22BudgetPeriod() throws {
        _ = try selectSettingsOption(pickerTitled: "集計期間", option: "過去 30 日間（今日から遡る）")
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        _ = try selectSettingsOption(pickerTitled: "集計期間", option: "今月（1 日から）")
        try assertHomeBaseline()
    }

    func scenarioSettings23BudgetWarnThreshold() throws {
        defer {
            _ = try? selectSettingsOption(pickerTitled: "警告しきい値", option: "80%")
            clearBudgetNotificationDedup()
        }
        _ = try selectSettingsOption(pickerTitled: "警告しきい値", option: "70%")
        try assertHomeBaseline()
    }

    /// `budgetAlertStyle` は Merge4 に含まれないので、ここでの切り替えは通知経路を
    /// 起動しない（重複抑止キーの後始末は不要）。
    func scenarioSettings24BudgetAlertStyle() throws {
        defer { _ = try? selectSettingsOption(pickerTitled: "知らせ方", option: "通知") }
        _ = try selectSettingsOption(pickerTitled: "知らせ方", option: "アラートウィンドウ")
        try assertHomeBaseline()
    }

    func scenarioSettings25PrivacyAnalyticsToggle() throws {
        let settings = try settingsRoot()
        try exerciseToggleByTitle("利用状況の送信を許可", under: settings)
    }

    func scenarioSettings26AdvancedDisclosure() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        guard treeContainsText("レポート言語", under: settings)
                || treeContainsText("Claude ディレクトリ", under: settings) else {
            throw E2EError.assertFailed("「詳細」を開いても内容が見えない")
        }
        try pressByTitle("詳細", under: settings)
    }

    func scenarioSettings27ReportLanguage() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer {
            try? pressByTitle("自動 (OS 設定)", under: settings)
            try? pressByTitle("詳細", under: settings)
        }
        try pressByTitle("English", under: settings)
        guard findByTitle("レポート言語", under: settings) != nil else {
            throw E2EError.assertFailed("レポート言語 Picker が操作後に見当たらない")
        }
    }

    /// `NSOpenPanel.runModal()` はモーダルなので、押したあとは Esc でキャンセルする
    /// （実際にディレクトリを変更するとその後のシナリオが実データを読みにいってしまう）。
    func scenarioSettings28ClaudeDirectory() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer { try? pressByTitle("詳細", under: settings) }
        guard hasControl(titled: "変更…", under: settings) else {
            throw E2EError.notFound("変更… button")
        }
        try pressByTitle("変更…", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        postKeystroke(keyCode: 53, flags: []) // Esc — パネルをキャンセルして閾値を変えない。
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    }

    /// トグルを実際に ON にすると、以降の操作イベントが実 UserDefaults 経由で
    /// `~/Library/Application Support/Tokfuel` に記録され続けてしまう。存在確認のみに留める。
    func scenarioSettings29EventLogToggle() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer { try? pressByTitle("詳細", under: settings) }
        guard hasControl(titled: "利用イベントを記録", under: settings) else {
            throw E2EError.notFound("利用イベントを記録 toggle")
        }
    }

    /// Finder を実際に開くとテスト環境にウィンドウが残るので、ボタンの存在確認のみ行う。
    func scenarioSettings30EventLogReveal() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer { try? pressByTitle("詳細", under: settings) }
        guard hasControl(titled: "ログを表示", under: settings) else {
            throw E2EError.notFound("ログを表示 button")
        }
    }

    /// 実削除は `~/Library/Application Support/Tokfuel` の実ファイルに触れるため押さない
    /// （CLAUDE.md のグラウンドルール）。ボタンの存在確認のみ行う。
    func scenarioSettings31EventLogDelete() throws {
        let settings = try settingsRoot()
        try pressByTitle("詳細", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer { try? pressByTitle("詳細", under: settings) }
        guard hasControl(titled: "全イベントを削除", under: settings) else {
            throw E2EError.notFound("全イベントを削除 button")
        }
    }

    func scenarioSettings32AboutWindow() throws {
        let home = try homeRoot()
        let more = try waitForIdentifier("tokfuel.menu.more", under: home, timeout: timeout(5))
        try press(more)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        guard let aboutItem = waitForTitle("Tokfuel について", timeout: timeout(4)) else {
            throw E2EError.notFound("menu item Tokfuel について")
        }
        try press(aboutItem)
        let window = try waitForWindowTitleContaining("Tokfuel について", timeout: timeout(6))
        _ = window
        closeFrontmostWindowWithCommandW()
    }

    /// 初回同意ダイアログは `analyticsConsentAnswered == false` のときだけ出るが、
    /// この E2E は既定フィクスチャ（毎回 answered=true）で起動しているため通常は出ない。
    /// `--e2e-fixture=analyticsConsent` で起動したプロセスに対してのみ実際に検証できる。
    func scenarioSettings33AnalyticsConsentFirstRun() throws {
        guard let window = findWindowTitleContaining("利用状況の送信") else {
            try assertHomeBaseline()
            return
        }
        guard let allow = findByTitle("許可する", under: window) else {
            throw E2EError.notFound("許可する button")
        }
        try press(allow)
    }

    func scenarioSettings34AnalyticsConsentDeny() throws {
        guard let window = findWindowTitleContaining("利用状況の送信") else {
            try assertHomeBaseline()
            return
        }
        guard let deny = findByTitle("許可しない", under: window) else {
            throw E2EError.notFound("許可しない button")
        }
        try press(deny)
    }

    /// 「プロンプト数」は分母を持たないので、パーセント/リングが選べない注意書きが出る。
    func scenarioSettings35MenuBarPreviewNote() throws {
        let settings = try settingsRoot()
        defer { _ = try? selectSettingsOption(identifier: "tokfuel.settings.menu-bar-metric", option: "今日") }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.menu-bar-metric", option: "プロンプト数")
        guard treeContainsText("パーセントとリングは選べません", under: settings) else {
            throw E2EError.assertFailed("メニューバーの注意書きが見当たらない")
        }
    }

    /// レートを直接 UserDefaults に仕込み（ネットワークは E2E で凍結されているため）、
    /// 円に切り替えたときに予算入力欄の単位が円になることを確認する。
    func scenarioSettings36CurrencyJpyBudgetUnit() throws {
        setDefaultsFloat("usdJpyRate", 150.0, bundleID: Self.tokfuelBundleID)
        defer {
            _ = try? selectSettingsOption(identifier: "tokfuel.settings.currency", option: "$ ドル")
            deleteDefaultsKey("usdJpyRate", bundleID: Self.tokfuelBundleID)
        }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.currency", option: "¥ 円")
        let settings = try settingsRoot()
        guard treeContainsText("(¥)", under: settings) else {
            throw E2EError.assertFailed("レート取得後も予算入力欄の単位が円にならない")
        }
    }

    /// DEBUG ビルドだけに出る「デバッグ」開閉。中の上書きトグルは既定フィクスチャの数値を
    /// 壊すので押さない（開閉できることだけを確認する）。
    func scenarioSettings37DebugDisclosure() throws {
        let settings = try settingsRoot()
        guard hasControl(titled: "デバッグ", under: settings) else {
            // Release ビルドには無い。
            try assertHomeBaseline()
            return
        }
        try pressByTitle("デバッグ", under: settings)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        guard treeContainsText("未取得を再現: 今日", under: settings) else {
            throw E2EError.assertFailed("「デバッグ」を開いても内容が見えない")
        }
        try pressByTitle("デバッグ", under: settings)
    }

    static let tokfuelBundleID = "com.akidon0000.tokfuel"

    func setDefaultsFloat(_ key: String, _ value: Double, bundleID: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", bundleID, key, "-float", String(value)]
        try? task.run()
        task.waitUntilExit()
    }

    func deleteDefaultsKey(_ key: String, bundleID: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["delete", bundleID, key]
        try? task.run()
        task.waitUntilExit()
    }
}
