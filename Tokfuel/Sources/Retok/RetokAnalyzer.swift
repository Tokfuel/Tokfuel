import Foundation

/// コスト分析の失敗。UI はこの localizedDescription をそのまま表示する。
enum RetokError: LocalizedError {
    /// 期間内にトランスクリプトが 1 つも無い（retok の exit 1 相当）。
    case noTranscripts(String)

    var errorDescription: String? {
        switch self {
        case .noTranscripts(let msg): return msg
        }
    }
}

/// トランスクリプト走査から RetokReport 組み立てまでのオーケストレーション
/// （retok.py main() + render() の JSON 出力部の移植）。同期関数なので、
/// 呼び出し側（RetokService）がバックグラウンドタスクに載せる。
enum RetokAnalyzer {

    /// retok の標準走査元: $CLAUDE_CONFIG_DIR/projects（設定時）+ ~/.claude/projects（重複除去）。
    static func defaultClaudeDirs() -> [URL] {
        var dirs: [URL] = []
        if let config = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !config.isEmpty {
            let expanded = (config as NSString).expandingTildeInPath
            dirs.append(URL(fileURLWithPath: expanded).appendingPathComponent("projects"))
        }
        dirs.append(FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects"))
        var seen = Set<String>()
        return dirs.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func defaultCodexDirs() -> [URL] {
        [CodexUsageReader.defaultSessionsDir]
    }

    static func analyze(days: Int, lang: String,
                        claudeDirs: [URL], codexDirs: [URL],
                        now: Date = Date()) throws -> RetokReport {
        let since = now.addingTimeInterval(-Double(days) * 86_400)
        let state = RetokScanState()
        RetokClaudeScanner.scan(dirs: claudeDirs, since: since, into: state)
        RetokCodexScanner.scan(dirs: codexDirs, since: since, into: state)

        // API トラフィックの無いセッションは落とす（retok と同じ）
        let sessions = state.sessions.filter { $0.value.requests > 0 }
        let messages = RetokMessages(lang: RetokMessages.resolveLang(lang))
        guard !sessions.isEmpty else {
            throw RetokError.noTranscripts(messages.format("no_transcripts"))
        }

        let values = Array(sessions.values)
        let totals = RetokAdvice.Totals(
            cost: values.reduce(0) { $0 + $1.cost },
            input: values.reduce(0) { $0 + $1.input },
            output: values.reduce(0) { $0 + $1.output },
            cacheRead: values.reduce(0) { $0 + $1.cacheRead },
            cacheWrite: values.reduce(0) { $0 + $1.cacheWrite },
            prompts: values.reduce(0) { $0 + $1.prompts },
            requests: values.reduce(0) { $0 + $1.requests })
        let (advice, hitRate) = RetokAdvice.build(sessions: values, totals: totals)

        let topSessions = sessions
            .sorted { $0.value.cost > $1.value.cost }
            .prefix(10)
            .map { sid, s in
                RetokReport.TopSession(session: sid, project: s.project ?? "?",
                                       cost: (s.cost * 10_000).rounded() / 10_000,
                                       prompts: s.prompts, maxContext: s.maxContext)
            }

        return RetokReport(
            periodDays: days,
            filesScanned: state.filesScanned,
            totals: RetokReport.Totals(cost: totals.cost, input: totals.input,
                                       output: totals.output, cacheRead: totals.cacheRead,
                                       cacheWrite: totals.cacheWrite, prompts: totals.prompts,
                                       requests: totals.requests),
            cacheHitRate: hitRate,
            perModel: state.perModel.mapValues {
                RetokReport.ModelUsage(cost: $0.cost, input: $0.input,
                                       output: $0.output, requests: $0.requests)
            },
            daily: state.daily.mapValues {
                RetokReport.DailyCost(cost: $0.cost, output: $0.output)
            },
            advice: advice.map {
                RetokReport.Advice(severity: $0.severity, key: $0.key,
                                   title: messages.format($0.key + "_title", params: $0.params),
                                   detail: messages.format($0.key + "_detail", params: $0.params))
            },
            topSessions: topSessions)
    }
}
