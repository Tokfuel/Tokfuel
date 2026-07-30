import Foundation
import Testing
@testable import Tokfuel

/// Codex ロールアウト fixture を一時ディレクトリに書いて走査する。
struct RetokCodexScannerTests {

    private static func iso(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle())
    }

    @Test func ロールアウトを集計し重複リプレイを除外する() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retok-codex-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("2026/07/29")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let t = Self.iso(Date().addingTimeInterval(-3600))
        let tokenCount = #"{"type":"event_msg","timestamp":"\#(t)","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":400,"output_tokens":100},"total_token_usage":{"total_tokens":1500}}}}"#
        let lines = [
            #"{"type":"session_meta","timestamp":"\#(t)","payload":{"session_id":"codex-1","cwd":"/Users/x/work/myproj"}}"#,
            #"{"type":"turn_context","timestamp":"\#(t)","payload":{"model":"gpt-5.4"}}"#,
            #"{"type":"event_msg","timestamp":"\#(t)","payload":{"type":"user_message","message":"do it"}}"#,
            // rate-limit だけの token_count（info: null）は無視
            #"{"type":"event_msg","timestamp":"\#(t)","payload":{"type":"token_count","info":null}}"#,
            tokenCount,
            tokenCount,  // 再開ロールアウトの履歴リプレイ → 累積カウンタで dedup
        ]
        try lines.joined(separator: "\n")
            .write(to: dir.appendingPathComponent("rollout-2026-07-29T10-00-00-abc.jsonl"),
                   atomically: true, encoding: .utf8)

        let state = RetokScanState()
        RetokCodexScanner.scan(dirs: [root], since: Date().addingTimeInterval(-30 * 86_400),
                               into: state)

        #expect(state.filesScanned == 1)
        let s = try #require(state.sessions["codex-1"])
        #expect(s.provider == "codex")
        #expect(s.project == "myproj")
        #expect(s.prompts == 1)
        #expect(s.requests == 1)
        #expect(s.input == 600)       // cached は内数なので除く
        #expect(s.cacheRead == 400)
        #expect(s.output == 100)
        #expect(s.maxContext == 1000)
        // gpt-5.4: (600*2.5 + 400*0.25 + 100*15) / 1e6
        #expect(abs(s.cost - 0.0031) < 1e-12)
        #expect(state.perModel["gpt-5.4"]?.requests == 1)
    }

    @Test func turn_contextが無ければ既定モデルはgpt5() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retok-codex-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("2026/07/29")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let t = Self.iso(Date().addingTimeInterval(-3600))
        try #"{"type":"event_msg","timestamp":"\#(t)","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5},"total_token_usage":{"total_tokens":15}}}}"#
            .write(to: dir.appendingPathComponent("rollout-2026-07-29T11-00-00-def.jsonl"),
                   atomically: true, encoding: .utf8)

        let state = RetokScanState()
        RetokCodexScanner.scan(dirs: [root], since: Date().addingTimeInterval(-30 * 86_400),
                               into: state)
        #expect(state.perModel.keys.contains("gpt-5"))
        // session_meta が無ければ sid はファイル名
        #expect(state.sessions.keys.contains("rollout-2026-07-29T11-00-00-def"))
    }
}
