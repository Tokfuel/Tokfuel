import Foundation
import Testing
@testable import Tokfuel

struct TranscriptScannerTests {
    @Test func 日別のプロンプト数とセッション数を集計する() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-transcript-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let prompt = """
        {"type":"user","timestamp":"2026-07-30T01:00:00Z","message":{"content":"hello"}}
        {"type":"user","timestamp":"2026-07-30T01:01:00Z","message":{"content":[{"type":"text","text":"again"}]}}
        {"type":"user","timestamp":"2026-07-30T01:02:00Z","message":{"content":[{"type":"tool_result"}]}}
        """
        try prompt.write(
            to: root.appendingPathComponent("session-1.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try prompt.write(
            to: root.appendingPathComponent("session-2.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let result = TranscriptScanner.scan(projectsDir: root)
        #expect(result == [DailyUsage(date: "2026-07-30", prompts: 4, sessions: 2)])
    }
}
