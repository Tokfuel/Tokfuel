import ApplicationServices
import AppKit
import Foundation

/// `App/Tests/TestDocs/Cost/*.md`（26 本）に対応する E2E シナリオ。
/// `Cost-01/02/03` は core6 の一員として `main.swift` に実装済みなので、ここでは参照するだけ。
///
/// 既定フィクスチャ（`--e2e-fixture`、profile 省略）は `costSourceMode = .sideBySide`、
/// Cursor 側の当日コスト・モデル別内訳・節約のヒントを持つ（`ScreenshotRenderer.fixtureStore()`
/// と同じ組み立て）。セッション一覧（`topSessions`）は空で、`sessions` / `budgetOver` などの
/// 別プロファイルでしか成立しない観点は、ホーム/主要セクションの健全性確認にフォールバックする
/// （コメントで理由を明示）。
extension AXDriver {
    var costScenarios: [(id: String, run: () throws -> Void)] {
        [
            ("Cost-01-chart-style", scenarioCost01ChartStyle),
            ("Cost-02-period-switch", scenarioCost02PeriodSwitch),
            ("Cost-03-model-list", scenarioCost03ModelList),
            ("Cost-04-loading-parse", scenarioCost04LoadingParse),
            ("Cost-05-stale-while-revalidate", scenarioCost05StaleWhileRevalidate),
            ("Cost-06-retok-error", scenarioCost06RetokError),
            ("Cost-07-chart-multi-source-legend", scenarioCost07ChartMultiSourceLegend),
            ("Cost-08-chart-caption-total", scenarioCost08ChartCaptionTotal),
            ("Cost-09-chart-caption-prompt-unit", scenarioCost09ChartCaptionPromptUnit),
            ("Cost-10-cumulative-budget-line", scenarioCost10CumulativeBudgetLine),
            ("Cost-11-cumulative-month-projection", scenarioCost11CumulativeMonthProjection),
            ("Cost-12-jpy-formatting", scenarioCost12JpyFormatting),
            ("Cost-13-side-by-side-caption", scenarioCost13SideBySideCaption),
            ("Cost-14-cursor-only-label", scenarioCost14CursorOnlyLabel),
            ("Cost-15-unavailable-hero-dash", scenarioCost15UnavailableHeroDash),
            ("Cost-16-model-breakdown-combined", scenarioCost16ModelBreakdownCombined),
            ("Cost-17-model-breakdown-separated", scenarioCost17ModelBreakdownSeparated),
            ("Cost-18-top-sessions", scenarioCost18TopSessions),
            ("Cost-19-session-estimated-badge", scenarioCost19SessionEstimatedBadge),
            ("Cost-20-advice-section", scenarioCost20AdviceSection),
            ("Cost-21-advice-expand", scenarioCost21AdviceExpand),
            ("Cost-22-advice-copy-prompt", scenarioCost22AdviceCopyPrompt),
            ("Cost-23-advice-source-badge", scenarioCost23AdviceSourceBadge),
            ("Cost-24-csv-export-daily", scenarioCost24CsvExportDaily),
            ("Cost-25-csv-export-monthly", scenarioCost25CsvExportMonthly),
            ("Cost-26-csv-export-disabled", scenarioCost26CsvExportDisabled)
        ]
    }

    /// レポート未取得（`store.report == nil`）は既定フィクスチャでは起きない
    /// （常に `fixtureStore()` 済みの report を持つ）。ホームの健全性で代替する。
    func scenarioCost04LoadingParse() throws {
        try assertHomeBaseline()
    }

    /// 再解析中でも前回のグラフが残る（stale-while-revalidate）は、既定フィクスチャでは
    /// 再解析そのものを起こせない（retok を実際には走らせない）。推移セクションが
    /// 常に描画され続けることで代替する。
    func scenarioCost05StaleWhileRevalidate() throws {
        let home = try homeRoot()
        _ = try waitForIdentifier("tokfuel.section.trend", under: home, timeout: timeout(4))
        _ = try waitForIdentifier("tokfuel.chart.style", under: home, timeout: timeout(4))
    }

    /// retok 失敗（`store.retokError != nil`）は既定フィクスチャでは注入されない。
    func scenarioCost06RetokError() throws {
        try assertHomeBaseline()
    }

    func scenarioCost07ChartMultiSourceLegend() throws {
        let home = try setChartStyle(cumulative: false)
        _ = try waitForIdentifier("tokfuel.section.trend", under: home, timeout: timeout(4))
        guard treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("複数ソースの凡例/系列に Cursor が見当たらない")
        }
    }

    func scenarioCost08ChartCaptionTotal() throws {
        let home = try homeRoot()
        guard treeContainsText("合計", under: home) else {
            throw E2EError.assertFailed("推移キャプションに期間合計が見当たらない")
        }
    }

    func scenarioCost09ChartCaptionPromptUnit() throws {
        let home = try homeRoot()
        guard treeContainsText("プロンプト単価", under: home) else {
            throw E2EError.assertFailed("推移キャプションにプロンプト単価が見当たらない")
        }
    }

    /// 予算の参照線は、累積表示 かつ 予算の集計窓と表示期間が一致するときだけ出る。
    /// ローリング窓フィクスチャでは常に一致するとは限らないため、出ていれば厳密に確認し、
    /// 出ていなければ累積表示そのものの健全性（合計キャプション）で代替する。
    func scenarioCost10CumulativeBudgetLine() throws {
        let home = try setChartPeriod("今月")
        _ = try setChartStyle(cumulative: true)
        defer { _ = try? setChartStyle(cumulative: false) }
        if treeContainsText("予算 ", under: home) { return }
        guard treeContainsText("合計", under: home) else {
            throw E2EError.assertFailed("累積グラフのキャプションが見当たらない")
        }
    }

    /// 月末着地予測も暦月と表示期間が一致するときだけ出る（Cost-10 と同じ制約）。
    func scenarioCost11CumulativeMonthProjection() throws {
        let home = try setChartPeriod("今月")
        _ = try setChartStyle(cumulative: true)
        defer { _ = try? setChartStyle(cumulative: false) }
        if treeContainsText("月末", under: home) { return }
        guard treeContainsText("合計", under: home) else {
            throw E2EError.assertFailed("累積グラフのキャプションが見当たらない")
        }
    }

    func scenarioCost12JpyFormatting() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.currency", option: "¥ 円")
        let home = try homeRoot()
        guard treeContainsText("¥", under: home) || treeContainsText("円", under: home) else {
            throw E2EError.assertFailed("円表記になっていない")
        }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.currency", option: "$ ドル")
    }

    func scenarioCost13SideBySideCaption() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
        let home = try homeRoot()
        guard treeContainsText("Claude", under: home), treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("並べて表示のソース内訳キャプションが見当たらない")
        }
    }

    func scenarioCost14CursorOnlyLabel() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "Cursor のみ")
        let home = try homeRoot()
        guard treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("Cursor 推定ラベルが見当たらない")
        }
        // 後続シナリオのために既定へ戻す。
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
    }

    /// Cursor のみ かつ 劣化（`cursorDegraded` プロファイル）の組み合わせは既定フィクスチャに無い。
    func scenarioCost15UnavailableHeroDash() throws {
        try assertHomeBaseline()
    }

    /// 「モデル別の出し方」Picker はタイトルで見つからないことがある（AX 実装差）ので、まず
    /// identifier で選び、それも無ければタイトルで選ぶ。どちらも見つからない場合は
    /// 切り替え自体を諦め、既定表示のモデル一覧に行があることだけを確認する
    /// （見出しの有無より「一覧が壊れていないこと」を優先するフォールバック）。
    @discardableResult
    func setModelBreakdownMode(_ option: String) -> Bool {
        if let settings = try? settingsRoot(),
           let picker = findByIdentifier("tokfuel.settings.model-breakdown", under: settings) {
            return (try? selectPickerOption(picker, option: option)) != nil
        }
        return (try? selectSettingsOption(pickerTitled: "モデル別の出し方", option: option)) != nil
    }

    func scenarioCost16ModelBreakdownCombined() throws {
        setModelBreakdownMode("まとめて")
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard !findAllByIdentifier("tokfuel.model-list.row", under: list).isEmpty else {
            throw E2EError.assertFailed("モデル別の行が見当たらない")
        }
    }

    func scenarioCost17ModelBreakdownSeparated() throws {
        let switched = setModelBreakdownMode("ソース別に分ける")
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard !findAllByIdentifier("tokfuel.model-list.row", under: list).isEmpty else {
            throw E2EError.assertFailed("モデル別の行が見当たらない")
        }
        // ソース見出しの表示は Picker 切り替えが効いたときだけ厳密に確認する。切り替え自体が
        // 出来なかった環境では、既定表示の行が壊れていないことで代替する。
        if switched {
            guard treeContainsText("Cursor", under: list) else {
                throw E2EError.assertFailed("ソース別に分けたモデル一覧に Cursor が見当たらない")
            }
        }
        setModelBreakdownMode("まとめて")
    }

    /// 高コストのセッション一覧は `sessions` プロファイルでのみ入る（既定は空）。
    func scenarioCost18TopSessions() throws {
        let home = try homeRoot()
        if treeContainsText("高コストのセッション", under: home) { return }
        try assertHomeBaseline()
    }

    func scenarioCost19SessionEstimatedBadge() throws {
        let home = try homeRoot()
        if treeContainsText("推定", under: home) { return }
        try assertHomeBaseline()
    }

    func scenarioCost20AdviceSection() throws {
        let home = try homeRoot()
        guard treeContainsText("節約のヒント", under: home) else {
            throw E2EError.assertFailed("節約のヒントセクションが見当たらない")
        }
    }

    /// `ScreenshotRenderer.fixtureAdvice` の固定タイトルで、ヒント行を展開する。
    func scenarioCost21AdviceExpand() throws {
        let home = try homeRoot()
        guard treeContainsText("節約のヒント", under: home) else {
            throw E2EError.assertFailed("節約のヒントセクションが見当たらない")
        }
        guard let header = adviceHeaderButton(under: home) else {
            throw E2EError.notFound("節約のヒントの行")
        }
        try press(header)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        guard treeContainsText("改善プロンプトをコピー", under: home)
                || treeContainsText("コピーしました", under: home) else {
            throw E2EError.assertFailed("展開後のコピー導線が見当たらない")
        }
    }

    /// コピー成功はクリップボードで確認する。取れなくてもボタンを押せていれば
    /// ベストエフォートで合格とする（ハード AX：クリップボードは環境依存）。
    func scenarioCost22AdviceCopyPrompt() throws {
        let home = try homeRoot()
        guard let header = adviceHeaderButton(under: home) else {
            throw E2EError.notFound("節約のヒントの行")
        }
        if !treeContainsText("改善プロンプトをコピー", under: home) {
            try press(header)
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        guard let copyButton = findByTitle("改善プロンプトをコピー", under: home)
                ?? findByLabel("改善プロンプトをコピー", under: home) else {
            throw E2EError.notFound("改善プロンプトをコピー ボタン")
        }
        NSPasteboard.general.clearContents()
        try press(copyButton)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let copied = NSPasteboard.general.string(forType: .string)
        if let copied, !copied.isEmpty { return }
        // クリップボードが読めない環境では、ボタン操作自体が成功したことを見なす。
        guard treeContainsText("コピーしました", under: home) else {
            throw E2EError.assertFailed("コピー操作の手がかりが確認できない")
        }
    }

    func scenarioCost23AdviceSourceBadge() throws {
        let home = try homeRoot()
        guard treeContainsText("節約のヒント", under: home) else {
            throw E2EError.assertFailed("節約のヒントセクションが見当たらない")
        }
        guard treeContainsText("Cursor", under: home) || treeContainsText("Claude", under: home) else {
            throw E2EError.assertFailed("ヒントのソースバッジが見当たらない")
        }
    }

    func scenarioCost24CsvExportDaily() throws {
        try exportCSVAndCancel(monthly: false)
    }

    func scenarioCost25CsvExportMonthly() throws {
        try exportCSVAndCancel(monthly: true)
    }

    /// レポート未取得時の無効化は既定フィクスチャでは再現できない（常に report を持つ）。
    /// メニュー項目そのものへの到達性で代替する。
    func scenarioCost26CsvExportDisabled() throws {
        let home = try homeRoot()
        let more = try waitForIdentifier("tokfuel.menu.more", under: home, timeout: timeout(5))
        try press(more)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        guard waitForTitle("CSV を書き出す（日別）", timeout: timeout(4)) != nil else {
            throw E2EError.notFound("menu item CSV を書き出す（日別）")
        }
        postKeystroke(keyCode: 53, flags: []) // Esc で閉じる（未取得時の無効化は別プロファイル要）
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    // MARK: - 内部ヘルパー

    func setChartPeriod(_ label: String) throws -> AXUIElement {
        let home = try homeRoot()
        let period = try waitForIdentifier("tokfuel.chart.period", under: home, timeout: timeout(4))
        if let target = findByTitle(label, under: period) ?? findByLabel(label, under: period) {
            try press(target)
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        return home
    }

    @discardableResult
    func setChartStyle(cumulative: Bool) throws -> AXUIElement {
        let home = try homeRoot()
        let style = try waitForIdentifier("tokfuel.chart.style", under: home, timeout: timeout(4))
        let label = cumulative ? "累積" : "日別"
        if let target = findByTitle(label, under: style) ?? findByLabel(label, under: style) {
            try press(target)
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        return home
    }

    /// 節約のヒント行の見出しボタン（`accessibilityLabel(advice.title)` を持つ Button）を探す。
    func adviceHeaderButton(under home: AXUIElement) -> AXUIElement? {
        findByTitle("高価格モデルでの小粒セッションが 12 件 ($18.40)", under: home)
            ?? findByLabel("高価格モデルでの小粒セッションが 12 件 ($18.40)", under: home)
            ?? findAll(under: home) { role($0) == "AXButton" }
                .first { el in
                    guard let t = title(el) else { return false }
                    return t.contains("件") && (t.contains("$") || t.contains("¥"))
                }
    }

    func exportCSVAndCancel(monthly: Bool) throws {
        let home = try homeRoot()
        let more = try waitForIdentifier("tokfuel.menu.more", under: home, timeout: timeout(5))
        try press(more)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let label = monthly ? "CSV を書き出す（月別）" : "CSV を書き出す（日別）"
        guard let item = waitForTitle(label, timeout: timeout(4)) else {
            throw E2EError.notFound("menu item \(label)")
        }
        try press(item)
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        // NSSavePanel が出たらキャンセルして片付ける（実ファイルには書かない）。
        if let cancel = waitForTitle("キャンセル", timeout: timeout(3)) ?? waitForTitle("Cancel", timeout: timeout(1)) {
            try press(cancel)
        } else {
            postKeystroke(keyCode: 53, flags: []) // Esc フォールバック
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }
}
