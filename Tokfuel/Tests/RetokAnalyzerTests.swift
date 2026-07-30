import Foundation
import Testing
@testable import Tokfuel

/// fixture JSONL を一時ディレクトリに書いて RetokAnalyzer を通す結合テスト。
/// 日付の期待値は本体と同じ RetokTime.localDayString で導出し、タイムゾーン非依存にする。
struct RetokAnalyzerTests {

    private static func iso(_ date: Date, fractional: Bool = false) -> String {
        fractional
            ? date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
            : date.formatted(Date.ISO8601FormatStyle())
    }

    /// root/<project>/... の一時ツリーを作り、テスト後に消す。
    private func withFixtureRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retok-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func write(lines: [String], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func analyze(root: URL, days: Int = 30, lang: String = "en") throws -> RetokReport {
        try RetokAnalyzer.analyze(days: days, lang: lang, claudeDirs: [root], codexDirs: [])
    }

    @Test func 基本の集計とコスト計算() throws {
        try withFixtureRoot { root in
            let now = Date()
            let t1 = Self.iso(now.addingTimeInterval(-3600), fractional: true)
            let t2 = Self.iso(now.addingTimeInterval(-3500))
            let file = root.appendingPathComponent("proj/sessionA.jsonl")
            try write(lines: [
                #"{"type":"user","timestamp":"\#(t1)","sessionId":"sessionA","cwd":"/Users/x/ghq/github.com/org/repo","message":{"role":"user","content":"hello"}}"#,
                #"{"type":"assistant","timestamp":"\#(t2)","sessionId":"sessionA","message":{"id":"m1","model":"claude-sonnet-5","usage":{"input_tokens":100,"output_tokens":200,"cache_read_input_tokens":1000,"cache_creation_input_tokens":500}}}"#,
                // 同じ message.id の続き行は二重計上しない
                #"{"type":"assistant","timestamp":"\#(t2)","sessionId":"sessionA","message":{"id":"m1","model":"claude-sonnet-5","usage":{"input_tokens":100,"output_tokens":200,"cache_read_input_tokens":1000,"cache_creation_input_tokens":500}}}"#,
            ], to: file)

            let report = try analyze(root: root)
            #expect(report.filesScanned == 1)
            #expect(report.totals.requests == 1)
            #expect(report.totals.prompts == 1)
            #expect(report.totals.input == 100)
            #expect(report.totals.output == 200)
            #expect(report.totals.cacheRead == 1000)
            #expect(report.totals.cacheWrite == 500)
            // sonnet: (100*3 + 200*15 + 1000*0.3 + 500*3.75) / 1e6
            let expected = (300.0 + 3000.0 + 300.0 + 1875.0) / 1e6
            #expect(abs(report.totals.cost - expected) < 1e-12)
            #expect(abs(report.cacheHitRate - 1000.0 / 1600.0) < 1e-12)
            // 日次キーはローカルタイムゾーン
            let day = RetokTime.localDayString(now.addingTimeInterval(-3500))
            #expect(report.daily[day] != nil)
            #expect(report.perModel["claude-sonnet-5"]?.requests == 1)
            #expect(report.topSessions.first?.session == "sessionA")
            #expect(report.topSessions.first?.project == "repo")   // cwd 末尾
            #expect(report.advice.first?.key == "adv_ok")
        }
    }

    @Test func プロンプト分類は人間の発話のみ数える() throws {
        try withFixtureRoot { root in
            let t = Self.iso(Date().addingTimeInterval(-3600))
            let file = root.appendingPathComponent("proj/s.jsonl")
            try write(lines: [
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":"real prompt"}}"#,
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":[{"type":"text","text":"block prompt"}]}}"#,
                // 以下はプロンプトに数えない
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#,
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":"Caveat: the messages below"}}"#,
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":"<local-command-stdout>x</local-command-stdout>"}}"#,
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","message":{"role":"user","content":"[Request interrupted by user]"}}"#,
                #"{"type":"user","timestamp":"\#(t)","sessionId":"s","isSidechain":true,"message":{"role":"user","content":"sidechain prompt"}}"#,
                // requests == 0 のセッションは落ちるため usage を 1 つ入れておく
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"s","message":{"id":"m1","model":"claude-haiku-4-5","usage":{"input_tokens":1,"output_tokens":1}}}"#,
            ], to: file)

            let report = try analyze(root: root)
            #expect(report.totals.prompts == 2)
        }
    }

    @Test func syntheticモデルはコスト計上しない() throws {
        try withFixtureRoot { root in
            let t = Self.iso(Date().addingTimeInterval(-3600))
            let file = root.appendingPathComponent("proj/s.jsonl")
            try write(lines: [
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"s","message":{"id":"syn1","model":"<synthetic>","usage":{"input_tokens":9999,"output_tokens":9999}}}"#,
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"s","message":{"id":"m1","model":"claude-haiku-4-5","usage":{"input_tokens":10,"output_tokens":20}}}"#,
            ], to: file)

            let report = try analyze(root: root)
            #expect(report.totals.requests == 1)
            #expect(report.totals.input == 10)
            #expect(report.perModel["<synthetic>"] == nil)
        }
    }

    @Test func サブエージェント分は親セッションに帰属する() throws {
        try withFixtureRoot { root in
            let t = Self.iso(Date().addingTimeInterval(-3600))
            try write(lines: [
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"sessionA","message":{"id":"m1","model":"claude-sonnet-5","usage":{"input_tokens":100,"output_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}"#,
            ], to: root.appendingPathComponent("proj/sessionA.jsonl"))
            try write(lines: [
                #"{"type":"assistant","timestamp":"\#(t)","message":{"id":"m2","model":"claude-sonnet-5","usage":{"input_tokens":50,"output_tokens":50}}}"#,
            ], to: root.appendingPathComponent("proj/sessionA/subagents/agent-1.jsonl"))

            let report = try analyze(root: root)
            #expect(report.filesScanned == 2)
            // 2 リクエストとも同一セッションへ
            #expect(report.topSessions.count == 1)
            #expect(report.topSessions.first?.session == "sessionA")
            #expect(report.totals.requests == 2)
            #expect(report.totals.input == 150)
            // maxContext はメインスレッドの行だけから決まる
            #expect(report.topSessions.first?.maxContext == 100)
        }
    }

    @Test func 期間より古いmtimeのファイルは走査しない() throws {
        try withFixtureRoot { root in
            let t = Self.iso(Date().addingTimeInterval(-3600))
            let old = root.appendingPathComponent("proj/old.jsonl")
            try write(lines: [
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"old","message":{"id":"m9","model":"claude-haiku-4-5","usage":{"input_tokens":1,"output_tokens":1}}}"#,
            ], to: old)
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(-40 * 86_400)],
                ofItemAtPath: old.path)
            let fresh = root.appendingPathComponent("proj/fresh.jsonl")
            try write(lines: [
                #"{"type":"assistant","timestamp":"\#(t)","sessionId":"fresh","message":{"id":"m1","model":"claude-haiku-4-5","usage":{"input_tokens":1,"output_tokens":1}}}"#,
            ], to: fresh)

            let report = try analyze(root: root)
            #expect(report.filesScanned == 1)
            #expect(report.topSessions.map(\.session) == ["fresh"])
        }
    }

    @Test func トランスクリプトが無ければnoTranscriptsを投げる() throws {
        try withFixtureRoot { root in
            #expect(throws: RetokError.self) {
                _ = try analyze(root: root)
            }
        }
    }

    @Test func メンバワイズinitでレポートを構築できる() {
        let report = RetokReport(
            periodDays: 7, filesScanned: 1,
            totals: RetokReport.Totals(cost: 1.5, input: 10, output: 20,
                                       cacheRead: 30, cacheWrite: 40, prompts: 2, requests: 3),
            cacheHitRate: 0.5,
            perModel: ["m": RetokReport.ModelUsage(cost: 1.5, input: 10, output: 20, requests: 3)],
            daily: ["2026-07-30": RetokReport.DailyCost(cost: 1.5, output: 20)],
            advice: [RetokReport.Advice(severity: "info", key: "adv_ok", title: "t", detail: "d")],
            topSessions: [])
        #expect(report.totals.cost == 1.5)
        #expect(report.cost(on: "2026-07-30") == 1.5)
    }
}
