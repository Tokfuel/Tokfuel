import Foundation

/// 他プロバイダ（Codex など）の 1 日分の使用量（CU-0009）。
/// Claude と共通で使える単位はセッション数。トークンはログが持つプロバイダのみ埋まる。
struct ProviderDayUsage: Sendable {
    let date: String          // YYYY-MM-DD
    var sessions: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
}

/// OpenAI Codex CLI のローカルセッションログを読む（CU-0009）。
/// 対象は `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` のみ。認証情報・設定には触れず、
/// ネットワークにも出ない（原則 1）。ログが無ければ空を返し、UI には現れない。
enum CodexUsageReader {
    /// 既定の走査元: ~/.codex/sessions
    static var defaultSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    /// セッションログを日別に集計する。1 ファイル = 1 セッション。
    static func scan(sessionsDir: URL = defaultSessionsDir) -> [ProviderDayUsage] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: sessionsDir, includingPropertiesForKeys: nil)
        else { return [] }

        var dayMap: [String: ProviderDayUsage] = [:]
        for case let url as URL in en where url.pathExtension == "jsonl" {
            guard let day = day(fromRolloutFileName: url.lastPathComponent),
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe)
            else { continue }
            var usage = dayMap[day] ?? ProviderDayUsage(date: day)
            usage.sessions += 1
            if let totals = sessionTotals(in: data) {
                usage.inputTokens += totals.input
                usage.outputTokens += totals.output
            }
            dayMap[day] = usage
        }
        return dayMap.values.sorted { $0.date < $1.date }
    }

    /// "rollout-2026-05-09T13-44-07-<uuid>.jsonl" → "2026-05-09"。
    /// ファイル名はローカル時刻なので、そのままローカルの日付として扱える。
    static func day(fromRolloutFileName name: String) -> String? {
        guard name.hasPrefix("rollout-"), name.count >= 18 else { return nil }
        let day = String(name.dropFirst("rollout-".count).prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4,
              parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return day
    }

    /// `token_count` イベントは `info: null`（rate_limits だけの更新）の場合があるため、
    /// 実データを持つ行だけをこのマーカーで選ぶ。
    private static let totalUsageMarker = Data("\"total_token_usage\"".utf8)

    /// セッションの累積トークン。`total_token_usage` は累積値なので、
    /// それを含む最後の 1 行だけを読めばよい（途中の行は捨てる）。
    static func sessionTotals(in data: Data) -> (input: Int, output: Int)? {
        var lastLine: Data?
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            var start = 0
            for i in 0...data.count {
                guard i == data.count || raw[i] == 0x0A else { continue }
                if i > start {
                    let line = Data(bytes: raw.baseAddress! + start, count: i - start)
                    if line.range(of: totalUsageMarker) != nil { lastLine = line }
                }
                start = i + 1
            }
        }
        guard let line = lastLine,
              let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = obj["payload"] as? [String: Any],
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any]
        else { return nil }
        // cached_input_tokens は input_tokens の内数なので足さない。
        return (input: total["input_tokens"] as? Int ?? 0,
                output: total["output_tokens"] as? Int ?? 0)
    }
}
