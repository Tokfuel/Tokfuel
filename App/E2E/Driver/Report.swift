import Foundation

/// 1 回の core6 実行結果。失敗時の PR コメントとアーティファクトの入力になる。
struct E2EReport: Codable {
    struct ScenarioResult: Codable {
        var id: String
        var status: String // "passed" | "failed" | "skipped"
        var elapsedMs: Int?
        var error: String?
    }

    var ok: Bool
    var failedScenario: String?
    var error: String?
    var explanation: String?
    var completedScenarios: [String]
    var scenarios: [ScenarioResult]
    var baselineIdentifiers: [String]
    var expectedScreens: [String]
    var updatedAt: String

    static let defaultPath = ".build/e2e/report.json"

    func write(to path: String = defaultPath) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// 生のエラー文字列から、レビュー向けの日本語説明を付ける。
    static func explain(error: String, scenario: String?) -> String {
        let sid = scenario ?? "不明なシナリオ"
        if error.contains("UI may have changed") || error.contains("present in last successful recording") {
            return """
            \(sid) で、前回成功時に存在した accessibilityIdentifier が見つかりませんでした。 \
            対象コントロールの identifier / ラベルが変わったか、ホーム UI が開いていない可能性があります。
            """
        }
        if error.hasPrefix("timed out:") {
            return "\(sid) で要素待ちがタイムアウトしました。表示遅延、AX ツリー未公開、または UI 改名が疑われます。"
        }
        if error.hasPrefix("not found:") {
            return "\(sid) で必須要素が見つかりませんでした。セレクタと画面状態を確認してください。"
        }
        if error.hasPrefix("assert failed:") {
            return "\(sid) の完了条件（Then）を満たしませんでした。表示内容か選択状態が期待と異なります。"
        }
        return "\(sid) で E2E が失敗しました。"
    }

    /// 失敗シナリオから、比較用に出すべき「正常画面」キーを決める。
    static func expectedScreens(for scenario: String?) -> [String] {
        switch scenario {
        case "Settings-01-open", "Settings-02-reflect":
            return ["settings", "popover"]
        default:
            return ["popover"]
        }
    }
}
