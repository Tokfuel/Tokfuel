import Foundation

/// Codex CLI 使用量を二次コスト源として読む CostDriver（CU-0009）。
///
/// retok は Codex CLI のセッションログ（`~/.codex/sessions/`）も走査でき、内蔵の OpenAI 価格表で
/// 実額を出せる（`retok.py` の `codex_cost()`）。推測レートは使わない — retok が持つ確定値のみ。
/// メインの Claude レポート呼び出しは `--provider claude` に絞っているため（Codex 分を二重計上
/// しないため）、Codex 分はこの driver が `--provider codex` で別プロセス実行して取る。
struct CodexCostDriver {
    let id = "codex"
    let displayName = "Codex"
}

extension CodexCostDriver: CostDriver {
    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: CodexUsageReader.defaultSessionsDir.path)
    }

    func dailyCosts(from: String, to: String) async -> [String: Double] {
        guard isAvailable else { return [:] }
        guard let days = Self.daysNeeded(from: from, reference: Date()) else { return [:] }
        guard let report = try? await RetokService.run(days: days, lang: "en", provider: "codex")
        else { return [:] }
        return report.daily
            .filter { $0.key >= from && $0.key <= to }
            .mapValues { $0.cost }
    }

    /// retok の `--days` は「reference からの遡り日数」なので、from を含めるために必要な日数に
    /// 変換する。from が未来やパース不能なら nil（呼び出し側は空を返す）。
    static func daysNeeded(from: String, reference: Date) -> Int? {
        guard let fromDate = dayFormatter.date(from: from) else { return nil }
        guard let day = Calendar.current.dateComponents([.day], from: fromDate, to: reference).day
        else { return nil }
        return max(1, day + 1)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
