import Foundation
import TokfuelCore
import TokfuelClaude

/// Codex CLI 使用量を二次コスト源として読む CostDriver（CU-0009）。
///
/// retok は Codex CLI のセッションログ（`~/.codex/sessions/`）も走査でき、内蔵の OpenAI 価格表で
/// 実額を出せる（`retok.py` の `codex_cost()`）。推測レートは使わない — retok が持つ確定値のみ。
/// メインの Claude レポート呼び出しは `--provider claude` に絞っているため（Codex 分を二重計上
/// しないため）、Codex 分はこの driver が `--provider codex` で別プロセス実行して取る。
public struct CodexCostDriver {
    public let id = "codex"
    public let displayName = "Codex"

    public init() {}

    /// 走査元。Codex CLI 未インストールならこのパスが無く、driver は一切表に出ない。
    public static var defaultSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }
}

extension CodexCostDriver: CostDriver {
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: Self.defaultSessionsDir.path)
    }

    /// モデル別内訳は持たない（retok の Codex 側は日別コストのみ使う）。
    public func snapshot(from: String, to: String) async -> CostSnapshot {
        guard isAvailable else { return .empty }
        guard let days = Self.daysNeeded(from: from, reference: Date()) else { return .empty }
        guard let report = try? await RetokService.run(days: days, lang: "en", provider: "codex")
        else { return .empty }
        let daily = report.daily
            .filter { $0.key >= from && $0.key <= to }
            .mapValues { $0.cost }
        return CostSnapshot(daily: daily, byModel: [:])
    }

    /// retok の `--days` は「reference からの遡り日数」なので、from を含めるために必要な日数に
    /// 変換する。from が未来やパース不能なら nil（呼び出し側は空を返す）。
    public static func daysNeeded(from: String, reference: Date) -> Int? {
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
