import Foundation
@testable import TokfuelUI

#if DEBUG

/// `ScreenshotRenderer` の画面名（＝ VRT / ui-preview のフィクスチャ名）と
/// TestDocs 観点 ID の対応。画面を足したらここ・`screenNames`・シナリオ MD を同じ PR で更新する。
enum VRTScreenMap {
    /// 1 画面 → 担保する観点 ID（複数可）。ID は `App/Tests/TestDocs/{Domain}/{nn}-{slug}.md` と一致させる。
    static let screensToViewpointIDs: [String: [String]] = [
        "popover": [
            "MenuBar-01-open-home",
            "Settings-09-cost-source-side-by-side",
        ],
        "popover-light": [
            "Settings-04-appearance",
        ],
        "popover-update": [
            "MenuBar-29-update-button-offer",
        ],
        "popover-cursor-degraded": [
            "Cursor-11-degraded-warning",
        ],
        "popover-cursor-signin": [
            "Cursor-12-sign-in-open-app",
        ],
        "popover-sessions": [
            "Cost-18-top-sessions",
        ],
        "popover-advice": [
            "Cost-20-advice-section",
        ],
        "popover-advice-expanded": [
            "Cost-21-advice-expand",
        ],
        // 末尾スクロールの共通土台。セッション／ヒント固有の観測は上の専用画面へ。
        "popover-scrolled": [
            "Cost-20-advice-section",
        ],
        // ⋯ メニュー展開。専用シナリオが無いあいだはホーム起票に紐づける。
        "popover-more-menu": [
            "MenuBar-01-open-home",
        ],
        "popover-period-today": [
            "Cost-02-period-switch",
        ],
        "popover-period-week": [
            "Cost-02-period-switch",
        ],
        "popover-period-month": [
            "Cost-02-period-switch",
        ],
        "popover-period-year": [
            "Cost-02-period-switch",
        ],
        "popover-jpy": [
            "Cost-12-jpy-formatting",
        ],
        "popover-claude-only": [
            "Settings-06-cost-source-claude-only",
        ],
        "popover-combined": [
            "Settings-05-cost-source-combined",
        ],
        "popover-cumulative": [
            "Cost-01-chart-style",
        ],
        "settings": [
            "Settings-01-open",
        ],
        "settings-jpy": [
            "Settings-36-currency-jpy-budget-unit",
        ],
        "settings-claude-only": [
            "Settings-06-cost-source-claude-only",
        ],
        "settings-advanced": [
            "Settings-26-advanced-disclosure",
        ],
        "settings-debug": [
            "Settings-37-debug-disclosure",
        ],
        "about": [
            "Settings-32-about-window",
        ],
        "budget-alert": [
            "Budget-10-alert-window-warning",
        ],
        "analytics-consent": [
            "Settings-33-analytics-consent-first-run",
        ],
    ]

    static var allScreenNames: [String] {
        screensToViewpointIDs.keys.sorted()
    }

    static func viewpointIDs(forScreen name: String) -> [String] {
        screensToViewpointIDs[name] ?? []
    }

    /// Markdown 表（TestDocs README / レビュー用）。
    static func markdownTable() -> String {
        var lines = [
            "| 画面名（スナップショット / ui-preview） | TestDocs 観点 ID |",
            "| --- | --- |",
        ]
        for screen in allScreenNames.sorted() {
            let ids = viewpointIDs(forScreen: screen)
            let cell = ids.isEmpty ? "（未紐付け）" : ids.map { "`\($0)`" }.joined(separator: ", ")
            lines.append("| `\(screen)` | \(cell) |")
        }
        return lines.joined(separator: "\n")
    }
}

#endif
