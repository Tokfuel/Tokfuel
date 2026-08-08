import TokamakDOM

/// Fixture-driven popover demo. This module is the source of truth for the
/// browsable web UI (SwiftUI-shaped composition via DemoNode trees).
public final class DemoPopoverView {
    public var fixtures: DemoFixtures
    private var screen: DemoScreen = .home
    private var adviceOpen: Set<Int> = []
    private var periodIndex: Int = 1
    private var menuOpen = false

    public enum DemoScreen {
        case home, settings, about
    }

    public init(fixtures: DemoFixtures = .sample) {
        self.fixtures = fixtures
    }

    public func mount(elementID: String = "app") {
        DemoDOM.mount(elementID: elementID, tree: { [weak self] in
            self?.tree() ?? .text("missing")
        }, onAction: { [weak self] action in
            self?.handle(action)
            DemoRenderScheduler.shared.requestRender()
        })
    }

    private func handle(_ action: String) {
        switch action {
        case "menu":
            menuOpen.toggle()
        case "settings":
            screen = .settings
            menuOpen = false
        case "about":
            screen = .about
            menuOpen = false
        case "home":
            screen = .home
        case let value where value.hasPrefix("period:"):
            if let index = Int(value.dropFirst("period:".count)) {
                periodIndex = index
            }
        case let value where value.hasPrefix("advice:"):
            if let index = Int(value.dropFirst("advice:".count)) {
                if adviceOpen.contains(index) { adviceOpen.remove(index) }
                else { adviceOpen.insert(index) }
            }
        default:
            break
        }
    }

    private func tree() -> DemoNode {
        let body: DemoNode
        switch screen {
        case .home: body = homeTree()
        case .settings: body = settingsTree()
        case .about: body = aboutTree()
        }
        return .frame(
            [
                .vstack([
                    .text("フィクスチャ専用の閲覧デモです。利用データは読み取らず、送信もしません。", style: .caption),
                    body,
                ], spacing: 12, padding: 16),
            ],
            minWidth: 392,
            minHeight: 560,
            background: "rgba(12,14,18,0.95)"
        )
    }

    private func homeTree() -> DemoNode {
        .frame(
            [
                .scroll([
                    hero(),
                    budgets(),
                    chart(),
                    models(),
                    sessions(),
                    advice(),
                ]),
                .divider,
                footer(),
            ],
            minWidth: 360,
            minHeight: 520,
            background: "rgba(36,36,38,0.92)",
            radius: 10
        )
    }

    private func hero() -> DemoNode {
        .vstack([
            .text("今日", style: .caption),
            .text(demoMoney(fixtures.todayTotal), style: .hero),
            .text(
                "Claude \(demoMoney(fixtures.claudeTodayCost)) · Cursor \(demoMoney(fixtures.cursorTodayCost))",
                style: .secondary
            ),
        ], spacing: 2)
    }

    private func budgets() -> DemoNode {
        .vstack([
            budgetRow(title: "予算 (今日)", spend: fixtures.todayTotal, limit: fixtures.dailyBudgetLimit),
            budgetRow(title: "予算 (今月)", spend: fixtures.budgetSpend, limit: fixtures.budgetLimit),
        ], spacing: 10)
    }

    private func budgetRow(title: String, spend: Double, limit: Double) -> DemoNode {
        let remain = max(0, limit - spend)
        let frac = min(1, spend / limit)
        let warn = frac >= fixtures.warnPercent
        let label = spend >= limit ? "超過" : "残り \(demoMoney(remain))"
        let color = warn ? "#ff9500" : "rgba(142,142,147,0.45)"
        return .vstack([
            .hstack([
                .text(title, style: .caption),
                .spacer,
                .text(label, style: warn ? .body : .secondary),
            ]),
            .bar(widthFraction: frac, color: color),
        ], spacing: 4)
    }

    private func chart() -> DemoNode {
        let maxDay = max(fixtures.daily.map { $0.claude + $0.cursor }.max() ?? 1, 0.01)
        let periods = ["今日", "今週", "今月", "今年"]
        let periodButtons: [DemoNode] = periods.enumerated().map { index, label in
            .button(label, id: "period:\(index)", style: periodIndex == index ? .body : .secondary)
        }
        let bars: [DemoNode] = fixtures.daily.map { day in
            let total = day.claude + day.cursor
            let h = max(2, (total / maxDay) * 88)
            let claudeF = total > 0 ? day.claude / total : 1
            let cursorF = total > 0 ? day.cursor / total : 0
            return .vstack([
                .stackedBar(claudeFraction: claudeF, cursorFraction: cursorF, height: h),
                .text(day.label, style: .tiny),
            ], spacing: 4)
        }
        return .vstack([
            .hstack([.text("推移", style: .caption), .spacer] + periodButtons, spacing: 6),
            .hstack(bars, spacing: 8),
            .text(
                "合計 \(demoMoney(fixtures.periodTotal)) · プロンプト単価 \(demoMoney(fixtures.promptUnitCost))",
                style: .secondary
            ),
        ], spacing: 8)
    }

    private func models() -> DemoNode {
        let maxCost = max((fixtures.claudeModels + fixtures.cursorModels).map(\.cost).max() ?? 1, 0.01)
        return .vstack([
            .text("モデル別", style: .caption),
            modelGroup("Claude", fixtures.claudeModels, maxCost),
            modelGroup("Cursor", fixtures.cursorModels, maxCost),
        ], spacing: 8)
    }

    private func modelGroup(_ title: String, _ rows: [DemoFixtures.Model], _ maxCost: Double) -> DemoNode {
        let items: [DemoNode] = rows.map { row in
            .hstack([
                .text(row.name, style: .caption),
                .bar(widthFraction: row.cost / maxCost, color: "rgba(142,142,147,0.45)"),
                .text(demoMoney(row.cost), style: .secondary),
            ], spacing: 8)
        }
        return .vstack([.text(title, style: .tiny)] + items, spacing: 6)
    }

    private func sessions() -> DemoNode {
        let rows: [DemoNode] = fixtures.sessions.map { session in
            .hstack([
                .text(session.title, style: .caption),
                .spacer,
                .text(demoMoney(session.cost), style: .secondary),
            ])
        }
        return .vstack([.text("高コストのセッション", style: .caption)] + rows, spacing: 6)
    }

    private func advice() -> DemoNode {
        var rows: [DemoNode] = [.text("節約のヒント", style: .caption)]
        for (index, item) in fixtures.advice.enumerated() {
            let open = adviceOpen.contains(index)
            rows.append(.button(
                "[\(item.source)] \(item.title) \(open ? "▼" : "›")",
                id: "advice:\(index)",
                style: .caption
            ))
            if open {
                rows.append(.text(item.detail, style: .secondary))
            }
        }
        return .vstack(rows, spacing: 6)
    }

    private func footer() -> DemoNode {
        var children: [DemoNode] = [
            .text("更新 \(fixtures.updatedAt)", style: .caption),
            .spacer,
        ]
        if menuOpen {
            children.append(.vstack([
                .button("設定…", id: "settings", style: .body),
                .button("Tokfuel について", id: "about", style: .body),
            ], spacing: 4, padding: 8))
        }
        children.append(.button("⋯", id: "menu", style: .body))
        return .hstack(children, spacing: 8)
    }

    private func settingsTree() -> DemoNode {
        .frame([
            .vstack([
                .text("設定", style: .headline),
                .text("フィクスチャ表示のみ。変更は保存されません。", style: .secondary),
                kv("通貨", "USD"),
                kv("コストソース", "並べて表示"),
                kv("日次予算", demoMoney(fixtures.dailyBudgetLimit)),
                kv("月次予算", demoMoney(fixtures.budgetLimit)),
                .button("戻る", id: "home", style: .body),
            ], spacing: 12, padding: 16),
        ], minWidth: 360, minHeight: 420, background: "rgba(36,36,38,0.92)", radius: 10)
    }

    private func aboutTree() -> DemoNode {
        .frame([
            .vstack([
                .text("Tokfuel", style: .title),
                .text("See what AI coding costs you, from the menu bar.", style: .secondary),
                .text("Version demo", style: .secondary),
                .text("retok © Daiki Matsudate (MIT)", style: .caption),
                .button("戻る", id: "home", style: .body),
            ], spacing: 8, padding: 16),
        ], minWidth: 360, minHeight: 420, background: "rgba(36,36,38,0.92)", radius: 10)
    }

    private func kv(_ title: String, _ value: String) -> DemoNode {
        .hstack([.text(title, style: .body), .spacer, .text(value, style: .secondary)])
    }
}
