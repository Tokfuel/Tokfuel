import Foundation

/// シナリオ ID → 実行クロージャのレジストリと、`--suite` / `--only` による絞り込み。
///
/// 各ドメインは `Scenarios{Domain}.swift` が `{domain}Scenarios` を実装する
/// （例: `budgetScenarios`）。ここではそれらを束ねるだけで、AX 操作そのものは持たない。
extension AXDriver {
    /// 132 本すべてのシナリオ（`App/Tests/TestDocs/**/*.md` の front matter `id:` と 1:1）。
    /// 順序はドメインごとの連番のまま（`--suite <Domain>` のときそのまま実行順になる）。
    var allScenarios: [(id: String, run: () throws -> Void)] {
        menuBarScenarios + costScenarios + cursorScenarios + budgetScenarios + settingsScenarios
    }

    /// ID の先頭セグメント（`Budget-01-...` → `Budget`）をドメイン名として使う。
    /// front matter の `primary_domain` と一致する（TestDocs の規約）。
    func domain(ofScenario id: String) -> String {
        String(id.split(separator: "-", maxSplits: 1).first ?? "")
    }

    /// `--suite` / `--only` に従ってレジストリから実行対象を選ぶ。
    /// - `only` が指定されていれば、それ 1 本だけを走らせる（`suite` は無視）。
    /// - `suite == "core6"`（既定）: 既存の 6 本を既存の順序で。
    /// - `suite == "all"`: 132 本すべてをドメイン順で。
    /// - それ以外: ドメイン名としてフィルタする（`Budget` / `Cost` / `Cursor` / `MenuBar` / `Settings`）。
    func selectScenarios(suite: String, only: String?) throws -> [(id: String, run: () throws -> Void)] {
        let registry = allScenarios
        if let only {
            guard let match = registry.first(where: { $0.id == only }) else {
                throw E2EError.notFound("--only \(only) は存在しないシナリオ ID です")
            }
            return [match]
        }
        switch suite {
        case "core6":
            let byID = Dictionary(uniqueKeysWithValues: registry.map { ($0.id, $0.run) })
            return try scenarioOrder.map { id in
                guard let run = byID[id] else {
                    throw E2EError.notFound("core6 の \(id) がレジストリに見つかりません")
                }
                return (id, run)
            }
        case "all":
            return registry
        default:
            let filtered = registry.filter { domain(ofScenario: $0.id) == suite }
            guard !filtered.isEmpty else {
                throw E2EError.notFound("--suite \(suite) に一致するシナリオがありません"
                    + "（core6 / all / Budget / Cost / Cursor / MenuBar / Settings のいずれか）")
            }
            return filtered
        }
    }
}
