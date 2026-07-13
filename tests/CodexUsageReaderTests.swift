import Foundation

// CodexUsageReader の headless テスト。実行方法:
//   swiftc -parse-as-library -swift-version 6 Tokfuel/Sources/ProviderUsage.swift \
//     tests/CodexUsageReaderTests.swift -o /tmp/codex_reader_tests && /tmp/codex_reader_tests
// フィクスチャは実際の ~/.codex/sessions/**/rollout-*.jsonl の形（匿名化済み）。

nonisolated(unsafe) var failures = 0
func expect(_ cond: Bool, _ label: String) {
    if cond { print("ok: \(label)") } else { failures += 1; print("FAIL: \(label)") }
}

// token_count は累積値なので、最後の行が勝つことをテストで固定する。
let fixture = """
{"timestamp":"2026-05-09T04:44:12.203Z","type":"session_meta","payload":{"id":"0000","cwd":"/tmp","originator":"codex_exec","cli_version":"0.117.0","model_provider":"openai"}}
{"timestamp":"2026-05-09T04:44:20.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":40,"output_tokens":10,"reasoning_output_tokens":2,"total_tokens":110},"last_token_usage":{"input_tokens":100,"cached_input_tokens":40,"output_tokens":10,"reasoning_output_tokens":2,"total_tokens":110},"model_context_window":353400},"rate_limits":{"limit_id":"codex","plan_type":"business"}}}
{"timestamp":"2026-05-09T04:45:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant"}}
{"timestamp":"2026-05-09T04:45:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":16609,"cached_input_tokens":9984,"output_tokens":194,"reasoning_output_tokens":27,"total_tokens":16803},"last_token_usage":{"input_tokens":16509,"cached_input_tokens":9944,"output_tokens":184,"reasoning_output_tokens":25,"total_tokens":16693},"model_context_window":353400},"rate_limits":{"limit_id":"codex","plan_type":"business"}}}
"""

@main
struct Tests {
    static func main() throws {
        // --- ファイル名 → 日付 ---
        expect(CodexUsageReader.day(fromRolloutFileName:
            "rollout-2026-05-09T13-44-07-019e0b0c-c6f1-7c43-b08f-20ff1514db69.jsonl") == "2026-05-09",
               "rollout file name yields date")
        expect(CodexUsageReader.day(fromRolloutFileName: "other.jsonl") == nil,
               "non-rollout name is skipped")
        expect(CodexUsageReader.day(fromRolloutFileName: "rollout-garbage.jsonl") == nil,
               "malformed date is skipped")

        // --- 累積トークンは最後の token_count が勝つ ---
        let totals = CodexUsageReader.sessionTotals(in: Data(fixture.utf8))
        expect(totals?.input == 16609, "input tokens from last token_count")
        expect(totals?.output == 194, "output tokens from last token_count")
        expect(CodexUsageReader.sessionTotals(in: Data("{}\n".utf8)) == nil,
               "file without token_count yields nil")

        // 実データに存在した形: 最後の token_count が info:null（rate_limits のみ）でも、
        // それより前の実データ行が勝つ。
        let withNullInfo = fixture + "\n" +
            #"{"timestamp":"2026-05-09T04:46:00.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"codex","plan_type":"business"}}}"#
        let totals2 = CodexUsageReader.sessionTotals(in: Data(withNullInfo.utf8))
        expect(totals2?.input == 16609, "info:null trailer does not clobber real totals")

        // --- ディレクトリ走査（一時ディレクトリに実配置と同じ構造を作る） ---
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-test-\(UUID().uuidString)/sessions/2026/05/09")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try fixture.write(to: root.appendingPathComponent(
            "rollout-2026-05-09T13-44-07-aaaa.jsonl"), atomically: true, encoding: .utf8)
        try fixture.write(to: root.appendingPathComponent(
            "rollout-2026-05-09T15-00-00-bbbb.jsonl"), atomically: true, encoding: .utf8)
        let days = CodexUsageReader.scan(
            sessionsDir: root.deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent())
        expect(days.count == 1, "two sessions on one day aggregate to one entry")
        expect(days.first?.sessions == 2, "session count is per file")
        expect(days.first?.inputTokens == 16609 * 2, "tokens summed across sessions")
        expect(CodexUsageReader.scan(sessionsDir: URL(fileURLWithPath: "/nonexistent")).isEmpty,
               "missing directory yields empty (section hidden)")
        try? FileManager.default.removeItem(at: root)

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all tests passed")
    }
}
