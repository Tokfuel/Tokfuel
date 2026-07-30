import Foundation

/// コスト分析の入口。retok.py のネイティブ移植（Sources/Retok/）をバックグラウンドで実行する。
/// python3 も外部プロセスも不要なので、素の Mac でも Cost タブが動く。
enum RetokService {
    /// レポートをバックグラウンドで生成して返す。
    /// projectsDir を渡すと Claude の走査元を上書きする（既定は ~/.claude/projects）。
    /// Codex（~/.codex/sessions）は retok と同様、常に既定の場所を走査する。
    static func run(days: Int, lang: String, projectsDir: URL? = nil) async throws -> RetokReport {
        let claudeDirs = projectsDir.map { [$0] } ?? RetokAnalyzer.defaultClaudeDirs()
        let codexDirs = RetokAnalyzer.defaultCodexDirs()
        return try await Task.detached(priority: .utility) {
            try RetokAnalyzer.analyze(days: days, lang: lang,
                                      claudeDirs: claudeDirs, codexDirs: codexDirs)
        }.value
    }
}
