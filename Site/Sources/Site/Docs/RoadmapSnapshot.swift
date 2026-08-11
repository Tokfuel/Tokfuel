import Ignite

/// Public snapshot of GitHub Project #1 (Tokfuel Roadmap).
/// Refresh when the board moves in a way readers should see on the site.
enum RoadmapSnapshot {
    static let asOf = "2026-08-08"
    static let doneCount = 32
    static let projectURL = "https://github.com/orgs/Tokfuel/projects/1"
    static let issuesURL = "https://github.com/Tokfuel/Tokfuel/issues"

    static let inProgress: [RoadmapItem] = [
        RoadmapItem(
            number: 137,
            titleJA: "TestDocs を導入しシナリオ運用を始める",
            titleEN: "Introduce TestDocs and start scenario-driven testing"
        ),
        RoadmapItem(
            number: 133,
            titleJA: "モデル別の長いモデル ID を全文表示する",
            titleEN: "Show full model IDs in the model breakdown"
        ),
        RoadmapItem(
            number: 120,
            titleJA: "Ignite サイトにドキュメントページを追加する",
            titleEN: "Add documentation pages to the Ignite site"
        ),
        RoadmapItem(
            number: 119,
            titleJA: "Sources 変更がある日は patch リリースを自動配布する",
            titleEN: "Auto-ship a patch release on days Sources change"
        ),
        RoadmapItem(
            number: 13,
            titleJA: "タグ push で App Store 提出と GitHub Release を自動化する",
            titleEN: "Automate App Store submission and GitHub Release on tag push"
        ),
        RoadmapItem(
            number: 5,
            titleJA: "コスト分析を Swift ネイティブにして python3 依存を外す",
            titleEN: "Reimplement cost analysis in native Swift and drop python3"
        ),
    ]

    static let todo: [RoadmapItem] = [
        RoadmapItem(
            number: 155,
            titleJA: "ブラウザで触れる閲覧デモを公開する",
            titleEN: "Publish a browsable interactive demo on the web"
        ),
        RoadmapItem(
            number: 130,
            titleJA: "Cursor included 枠の残りを表示する",
            titleEN: "Show Cursor included allowance remaining"
        ),
        RoadmapItem(
            number: 95,
            titleJA: "ui-preview の画像配信を GitHub 添付に切り替える",
            titleEN: "Switch ui-preview image hosting to GitHub attachments"
        ),
        RoadmapItem(
            number: 90,
            titleJA: "トランスクリプト無しをエラーではなく空状態として扱う",
            titleEN: "Treat missing transcripts as empty, not an error"
        ),
        RoadmapItem(
            number: 76,
            titleJA: "アップデート確認の間隔を1時間にする",
            titleEN: "Check for updates every hour"
        ),
        RoadmapItem(
            number: 66,
            titleJA: "今日の予算超過時にメニューバー表示を切り替える",
            titleEN: "Switch menu bar readout after today's budget is exceeded"
        ),
        RoadmapItem(
            number: 51,
            titleJA: "習慣タブでストリークと時間帯パターンを見せる",
            titleEN: "Show streaks and time-of-day patterns in a Habits tab"
        ),
        RoadmapItem(
            number: 50,
            titleJA: "活動タブで Skill / MCP / サブエージェントを見せる",
            titleEN: "Show Skill / MCP / subagent activity in an Activity tab"
        ),
        RoadmapItem(
            number: 49,
            titleJA: "ポップオーバーをタブ切り替え構造にする",
            titleEN: "Make the popover a tabbed shell"
        ),
        RoadmapItem(
            number: 48,
            titleJA: "ポップオーバーに複数コンセプトを共存させる",
            titleEN: "Let multiple concepts coexist in the popover"
        ),
        RoadmapItem(
            number: 46,
            titleJA: "予算通知の有効・音・しきい値を分けて設定する",
            titleEN: "Make budget notification enable, sound, and thresholds configurable"
        ),
        RoadmapItem(
            number: 36,
            titleJA: "ラベルで起動する AI コードレビューを追加する",
            titleEN: "Add label-triggered AI code review"
        ),
        RoadmapItem(
            number: 30,
            titleJA: "価格表に無いモデル ID を Cost タブで知らせる",
            titleEN: "Surface unpriced model IDs in the Cost tab"
        ),
        RoadmapItem(
            number: 9,
            titleJA: "Windows / Linux 対応を検討する",
            titleEN: "Explore Windows / Linux support"
        ),
    ]
}

struct RoadmapItem {
    let number: Int
    let titleJA: String
    let titleEN: String

    var issueURL: String {
        "https://github.com/Tokfuel/Tokfuel/issues/\(number)"
    }

    func title(_ language: DocsLanguage) -> String {
        language == .ja ? titleJA : titleEN
    }

    var tfLabel: String {
        String(format: "TF-%04d", number)
    }
}

/// Shared roadmap lists for EN / JA docs pages.
struct RoadmapLists: HTML {
    var language: DocsLanguage

    private var isJA: Bool { language == .ja }

    var body: some HTML {
        Text(isJA ? "進行中" : "In progress")
            .docsSubheading()

        roadmapList(RoadmapSnapshot.inProgress)

        Text(isJA ? "これから" : "Todo")
            .docsSubheading()

        roadmapList(RoadmapSnapshot.todo)

        Text(isJA ? "完了" : "Done")
            .docsSubheading()

        Text(isJA
             ? "ボード上で完了になっている項目は \(RoadmapSnapshot.doneCount) 件です。個別の履歴は GitHub Issue を見てください。"
             : "\(RoadmapSnapshot.doneCount) items are marked Done on the board. See individual GitHub Issues for history.")
            .foregroundStyle(.secondary)
    }

    @HTMLBuilder
    private func roadmapList(_ items: [RoadmapItem]) -> some HTML {
        List {
            for item in items {
                ListItem {
                    Text {
                        Code(item.tfLabel)
                        " "
                        Link(item.title(language), target: item.issueURL)
                            .linkStyle(.underline(.heavy))
                    }
                }
            }
        }
    }
}
