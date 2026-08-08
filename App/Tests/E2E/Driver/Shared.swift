import ApplicationServices
import AppKit
import Foundation

/// 全ドメインのシナリオ実装（`Scenarios*.swift`）が共通で使うヘルパー。
/// AX の低レベル操作は `main.swift` の `AXDriver` にあり、ここはそれらを組み合わせた
/// 「よくある操作・よくある確認」を集める。
extension AXDriver {
    // MARK: - ホーム / 設定ウィンドウの取得

    /// ホームを開いて（未オープンなら開いて）ルート要素を返す。
    @discardableResult
    func homeRoot() throws -> AXUIElement {
        try ensureHomeOpen()
        return try requireIdentifier("tokfuel.home")
    }

    /// 設定ウィンドウを開いて（未オープンなら「⋯」→「設定」で開いて）ルート要素を返す。
    /// identifier が取れない環境ではウィンドウタイトルにフォールバックする
    /// （DEBUG ビルドはタイトルに `（DEBUG）` が付くため、部分一致で見る）。
    @discardableResult
    func settingsRoot() throws -> AXUIElement {
        try openSettingsFromHome()
        if let el = findByIdentifier("tokfuel.settings") { return el }
        if let el = try? waitForWindowTitleContaining("設定", timeout: timeout(5)) { return el }
        return try waitForWindowTitle("Tokfuel 設定", timeout: timeout(5))
    }

    /// 設定を閉じてホームへ戻る（次のシナリオを素の状態から始めるための後始末）。
    func closeSettingsIfOpen() {
        guard let settings = findByIdentifier("tokfuel.settings")
                ?? findWindowTitleContaining("設定") else { return }
        _ = AXUIElementPerformAction(settings, "AXRaise" as CFString)
        postKeyCommandW()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    // MARK: - テキスト検索（フィクスチャ依存の弱い確認向け）

    /// ツリー中の title / value / description のどこかに `text` を含む要素があるか。
    func treeContainsText(_ text: String, under root: AXUIElement) -> Bool {
        !findAll(under: root) { el in
            containsText(text, in: el)
        }.isEmpty
    }

    func containsText(_ text: String, in el: AXUIElement) -> Bool {
        (title(el)?.contains(text) ?? false)
            || (value(el)?.contains(text) ?? false)
            || (description(el)?.contains(text) ?? false)
    }

    /// ツリー全体を 1 つの文字列に連結する（部分一致のフォールバック確認用）。
    func flatText(under root: AXUIElement) -> String {
        collectTitles(under: root).joined(separator: " ")
    }

    // MARK: - コントロール操作

    /// タイトル一致で見つけて押す（Picker のオプション・Toggle・Button 共通）。
    func pressByTitle(_ label: String, under root: AXUIElement) throws {
        guard let target = findByTitle(label, under: root) ?? findByLabel(label, under: root) else {
            throw E2EError.notFound("control titled \(label)")
        }
        try press(target)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    /// あれば押す・無ければ何もしない（存在しない組み合わせでも落とさない緩い版）。
    @discardableResult
    func pressByTitleIfPresent(_ label: String, under root: AXUIElement) -> Bool {
        guard let target = findByTitle(label, under: root) ?? findByLabel(label, under: root) else {
            return false
        }
        try? press(target)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        return true
    }

    /// タイトルを持つコントロールが存在するか（押さない・存在確認だけ）。
    func hasControl(titled label: String, under root: AXUIElement) -> Bool {
        findByTitle(label, under: root) != nil || findByLabel(label, under: root) != nil
    }

    /// `representationRow` のような「複数の子要素（アイコン + テキスト + プレビュー）を持つ
    /// Button」を、内側のテキスト一致で見つけて押す。
    func pressButtonContaining(_ label: String, under root: AXUIElement) throws {
        let buttons = findAll(under: root) { role($0) == "AXButton" }
        for button in buttons where !findAll(under: button, where: {
            title($0) == label || value($0) == label
        }).isEmpty {
            try press(button)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            return
        }
        throw E2EError.notFound("button containing \(label)")
    }

    /// トグルの現在値（0/1）。取れなければ nil。
    func toggleValue(_ el: AXUIElement) -> Int? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return ref as? Int
    }

    // MARK: - 設定ウィンドウの Picker / 行

    /// タイトルで見つかる Picker から、指定ラベルの選択肢を押す。
    @discardableResult
    func selectSettingsOption(pickerTitled pickerTitle: String, option: String) throws -> AXUIElement {
        let settings = try settingsRoot()
        guard let picker = findByTitle(pickerTitle, under: settings) else {
            throw E2EError.notFound("picker \(pickerTitle)")
        }
        try selectPickerOption(picker, option: option)
        return picker
    }

    /// accessibilityIdentifier で見つかる Picker から、指定ラベルの選択肢を押す。
    @discardableResult
    func selectSettingsOption(identifier: String, option: String) throws -> AXUIElement {
        let settings = try settingsRoot()
        let picker = try waitForIdentifier(identifier, under: settings, timeout: timeout(4))
        try selectPickerOption(picker, option: option)
        return picker
    }

    /// Picker の選択肢を押す。`.radioGroup` / `.segmented` は選択肢が Picker の子要素として
    /// 木に並ぶが、明示指定の無い既定スタイル（`.menu` 相当）はメニューを開くまで選択肢が
    /// 現れない。まず子要素から探し、無ければ Picker 自体を押してメニューを開き、
    /// 画面全体からタイトルで選択肢を探す。
    func selectPickerOption(_ picker: AXUIElement, option: String) throws {
        if let child = findByTitle(option, under: picker) ?? findByLabel(option, under: picker) {
            try press(child)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            return
        }
        try press(picker)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        guard let item = waitForTitle(option, timeout: timeout(3)) else {
            throw E2EError.notFound("picker option \(option)")
        }
        try press(item)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    /// メニューバー「表現」の行（Picker ではなく独自 Button）をラベルで選ぶ。
    func selectMenuBarRepresentation(_ label: String) throws {
        let settings = try settingsRoot()
        try pressButtonContaining(label, under: settings)
    }

    // MARK: - ステータス項目

    func assertStatusItemPresent() throws {
        guard findStatusItem() != nil else {
            throw E2EError.notFound("tokfuel.status-item")
        }
    }

    @discardableResult
    func statusItemElement() throws -> AXUIElement {
        guard let item = findStatusItem() else { throw E2EError.notFound("tokfuel.status-item") }
        return item
    }

    /// ステータス項目の現在のタイトル文字列（数字・記号を含む表示テキスト）。
    func statusItemTitle() -> String? {
        guard let item = findStatusItem() else { return nil }
        return title(item) ?? description(item)
    }

    // MARK: - ウィンドウ

    /// ウィンドウタイトルの部分一致でポーリングして見つける（DEBUG マーカー付きタイトル対応）。
    func waitForWindowTitleContaining(_ substring: String, timeout: TimeInterval) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let el = findWindowTitleContaining(substring) { return el }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        throw E2EError.timedOut("window containing \(substring)")
    }

    func findWindowTitleContaining(_ substring: String) -> AXUIElement? {
        guard let windows = copyArray(app, kAXWindowsAttribute as String) else { return nil }
        return windows.first { title($0)?.contains(substring) ?? false }
    }

    /// フロントウィンドウを Cmd+W で閉じる（About / アラートなど、閉じるボタンを持つパネル用）。
    /// AX の `AXClose` アクションはウィンドウ自体には無いことが多いため、キーボード操作に頼る。
    func closeFrontmostWindowWithCommandW() {
        postKeyCommandW()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    func postKeyCommandW() {
        postKeystroke(keyCode: 13, flags: .maskCommand) // 'w'
    }

    func postKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - 予算アラート

    /// 予算レベルの重複抑止（同一 period 中は 1 回だけ）を回避して確実に再通知させる。
    /// `集計期間` を一度切り替えて戻すと periodKey が変わり、`BudgetMonitor.deliveryIfNeeded`
    /// が「新しい期間」として扱ってレベルを `.ok` にリセットするため、消費・上限が変わらなくても
    /// 再度アラート/通知が飛ぶ（`App.swift` の `Merge4` 経由で `notifyBudgetIfNeeded()` が走る）。
    /// 実 UserDefaults の重複抑止キーを書き換えるので、呼び出し側は必ず
    /// `clearBudgetNotificationDedup()` を defer で呼び、実アプリの今月の通知状態を汚さない
    /// ようにすること。上限が 0（未設定）だと `集計期間` 自体が無いので nil を返す。
    @discardableResult
    func retriggerBudgetAlert(style: String = "アラートウィンドウ") throws -> AXUIElement? {
        _ = try selectSettingsOption(pickerTitled: "知らせ方", option: style)
        let settings = try settingsRoot()
        guard let picker = findByTitle("集計期間", under: settings) else { return nil }
        try selectPickerOption(picker, option: "過去 30 日間（今日から遡る）")
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        if let picker2 = findByTitle("集計期間", under: settings) {
            try selectPickerOption(picker2, option: "今月（1 日から）")
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        return try? waitForWindowTitleContaining("予算アラート", timeout: timeout(5))
    }

    /// 予算アラートウィンドウが開いていれば「閉じる」で閉じる（無ければ何もしない）。
    func closeBudgetAlertIfOpen() {
        guard let window = findWindowTitleContaining("予算アラート") else { return }
        if let closeButton = findByTitle("閉じる", under: window) {
            try? press(closeButton)
        } else {
            _ = AXUIElementPerformAction(window, "AXRaise" as CFString)
            postKeyCommandW()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    /// `retriggerBudgetAlert()` が書き換えた実 UserDefaults の重複抑止キーを消す
    /// （テスト起因の状態が、実アプリの今月の通知判定に残らないための後始末）。
    func clearBudgetNotificationDedup() {
        for key in ["budgetNotifiedLevel", "budgetNotifiedPeriod",
                    "budgetNotifiedLevel-daily", "budgetNotifiedPeriod-daily"] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            task.arguments = ["delete", "com.akidon0000.tokfuel", key]
            try? task.run()
            task.waitUntilExit()
        }
    }

    // MARK: - フォールバック用の最小確認

    /// フィクスチャ依存で厳密に確認できないシナリオの最終防衛線。
    /// ホームが開けて主要セクションが見えることだけを保証する（空のスタブにはしない）。
    func assertHomeBaseline() throws {
        let home = try homeRoot()
        _ = try waitForIdentifier("tokfuel.hero.today", under: home, timeout: timeout(5))
    }
}
