import Foundation
import TokfuelCore
import TokfuelClaude

/// 実額を出せる（`retok.py` の `codex_cost()`）。推測レートは使わない — retok が持つ確定値のみ。
/// しないため）、Codex 分はこの driver が `--provider codex` で別プロセス実行して取る。
public struct CodexCostDriver {
    public let id = "codex"
    public let displayName = "Codex"

    public init() {}

    public static var defaultSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }
}

extension CodexCostDriver: CostDriver {
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: Self.defaultSessionsDir.path)
    }

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
