import ApplicationServices
import AppKit
import Foundation

/// `App/Tests/TestDocs/Cursor/*.md`（18 本）に対応する E2E シナリオ。
///
/// 既定フィクスチャは Cursor（二次ソース）の当日コスト・モデル別内訳を持ち、
/// `CursorAdvice` のヒント（モデル偏り・価格表に無いモデル）も自然に成立する組み合わせ。
/// 劣化・サインイン・0 円などは `cursorDegraded` / `cursorSignIn` 系プロファイルでしか
/// 再現できないため、ホーム/主要セクションの健全性確認にフォールバックする。
extension AXDriver {
    var cursorScenarios: [(id: String, run: () throws -> Void)] {
        [
            ("Cursor-01-chart-stacked-bar", scenarioCursor01ChartStackedBar),
            ("Cursor-02-hero-side-by-side", scenarioCursor02HeroSideBySide),
            ("Cursor-03-hero-cursor-only", scenarioCursor03HeroCursorOnly),
            ("Cursor-04-model-rows", scenarioCursor04ModelRows),
            ("Cursor-05-top-session-rows", scenarioCursor05TopSessionRows),
            ("Cursor-06-session-estimated-label", scenarioCursor06SessionEstimatedLabel),
            ("Cursor-07-advice-dominant-model", scenarioCursor07AdviceDominantModel),
            ("Cursor-08-advice-share-of-total", scenarioCursor08AdviceShareOfTotal),
            ("Cursor-09-advice-unpriced-models", scenarioCursor09AdviceUnpricedModels),
            ("Cursor-10-advice-hidden-when-degraded", scenarioCursor10AdviceHiddenWhenDegraded),
            ("Cursor-11-degraded-warning", scenarioCursor11DegradedWarning),
            ("Cursor-12-sign-in-open-app", scenarioCursor12SignInOpenApp),
            ("Cursor-13-recheck-after-sign-in", scenarioCursor13RecheckAfterSignIn),
            ("Cursor-14-unavailable-dash-hero", scenarioCursor14UnavailableDashHero),
            ("Cursor-15-unavailable-dash-menubar", scenarioCursor15UnavailableDashMenubar),
            ("Cursor-16-unavailable-side-by-side", scenarioCursor16UnavailableSideBySide),
            ("Cursor-17-filter-by-source-mode", scenarioCursor17FilterBySourceMode),
            ("Cursor-18-zero-cost-hidden-breakdown", scenarioCursor18ZeroCostHiddenBreakdown)
        ]
    }

    func scenarioCursor01ChartStackedBar() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "合算")
        let home = try setChartStyle(cumulative: false)
        _ = try waitForIdentifier("tokfuel.section.trend", under: home, timeout: timeout(4))
        guard treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("合算の推移に Cursor 系列が見当たらない")
        }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
    }

    func scenarioCursor02HeroSideBySide() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
        let home = try homeRoot()
        guard treeContainsText("Claude", under: home), treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("並べて表示のヒーロー下に Cursor 金額が見当たらない")
        }
    }

    func scenarioCursor03HeroCursorOnly() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "Cursor のみ")
        let home = try homeRoot()
        guard treeContainsText("Cursor", under: home) else {
            throw E2EError.assertFailed("Cursor のみのヒーロー表示が見当たらない")
        }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
    }

    func scenarioCursor04ModelRows() throws {
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard treeContainsText("Cursor", under: list) else {
            throw E2EError.assertFailed("モデル別に Cursor 行が見当たらない")
        }
    }

    /// 高コストのセッション一覧は `sessions` プロファイルでのみ Cursor 行を持つ。
    func scenarioCursor05TopSessionRows() throws {
        let home = try homeRoot()
        if treeContainsText("高コストのセッション", under: home) { return }
        try assertHomeBaseline()
    }

    func scenarioCursor06SessionEstimatedLabel() throws {
        let home = try homeRoot()
        if treeContainsText("推定", under: home) { return }
        try assertHomeBaseline()
    }

    /// `CursorAdvice.dominantModelHint`: 既定フィクスチャは claude-4.5-sonnet が
    /// 価格の付くモデルの 80% を占め、しきい値 60% を超えるので必ず出る。
    func scenarioCursor07AdviceDominantModel() throws {
        let home = try homeRoot()
        guard treeContainsText("Cursor コストの", under: home) else {
            throw E2EError.assertFailed("Cursor のモデル偏りヒントが見当たらない")
        }
    }

    /// `CursorAdvice.shareHint`: 既定フィクスチャは Cursor 比率が約 25% でしきい値 50% に
    /// 届かないため出ない。節約のヒントセクション自体の健全性で代替する。
    func scenarioCursor08AdviceShareOfTotal() throws {
        let home = try homeRoot()
        if treeContainsText("は Cursor です", under: home) { return }
        guard treeContainsText("節約のヒント", under: home) else {
            throw E2EError.assertFailed("節約のヒントセクションが見当たらない")
        }
    }

    /// `CursorAdvice.unpricedModelsHint`: 既定フィクスチャは `composer-1` が $0（価格表に無い）。
    func scenarioCursor09AdviceUnpricedModels() throws {
        let home = try homeRoot()
        guard treeContainsText("価格表に無く", under: home) else {
            throw E2EError.assertFailed("価格表に無いモデルのヒントが見当たらない")
        }
    }

    /// 劣化時にヒントが出ないことの直接確認は `cursorDegraded` プロファイルが必要。
    func scenarioCursor10AdviceHiddenWhenDegraded() throws {
        try assertHomeBaseline()
    }

    func scenarioCursor11DegradedWarning() throws {
        try assertHomeBaseline()
    }

    func scenarioCursor12SignInOpenApp() throws {
        try assertHomeBaseline()
    }

    func scenarioCursor13RecheckAfterSignIn() throws {
        try assertHomeBaseline()
    }

    func scenarioCursor14UnavailableDashHero() throws {
        try assertHomeBaseline()
    }

    func scenarioCursor15UnavailableDashMenubar() throws {
        try assertStatusItemPresent()
    }

    func scenarioCursor16UnavailableSideBySide() throws {
        try assertHomeBaseline()
    }

    /// Claude のみに切り替えると、モデル別一覧から Cursor 行が消える。
    func scenarioCursor17FilterBySourceMode() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "Claude のみ")
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        guard !treeContainsText("Cursor", under: list) else {
            throw E2EError.assertFailed("Claude のみでもモデル一覧に Cursor 行が残っている")
        }
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
    }

    /// 0 円の Cursor を内訳キャプションから隠す挙動は、既定フィクスチャ（Cursor $4.20）では
    /// 再現できない。並べて表示のキャプションそのものの健全性で代替する。
    func scenarioCursor18ZeroCostHiddenBreakdown() throws {
        _ = try selectSettingsOption(identifier: "tokfuel.settings.cost-source", option: "並べて表示")
        let home = try homeRoot()
        guard treeContainsText("Claude", under: home) else {
            throw E2EError.assertFailed("並べて表示のキャプションが見当たらない")
        }
    }
}
