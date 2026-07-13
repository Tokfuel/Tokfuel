import Foundation

// UsageEventLog の headless テスト。実行方法:
//   swiftc -parse-as-library Tokfuel/Sources/UsageEventLog.swift tests/UsageEventLogTests.swift \
//     -o /tmp/usage_event_log_tests && /tmp/usage_event_log_tests
// （BudgetMonitor / TranscriptScanner と同じ、小さな swiftc ハーネスのパターン）

nonisolated(unsafe) var failures = 0   // 単一スレッドのテストランナー専用
func expect(_ cond: Bool, _ label: String) {
    if cond { print("ok: \(label)") } else { failures += 1; print("FAIL: \(label)") }
}

func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

@main
struct Tests {
    static func main() throws {
        // --- ファイル名（グレゴリオ暦固定。和暦などの地域設定に依存しない） ---
        expect(UsageEventLog.fileName(for: date("2026-07-13T10:00:00Z")) == "2026-07.jsonl",
               "fileName is Gregorian YYYY-MM regardless of region settings")

        // --- 保持期間（12 か月） ---
        let now = date("2026-07-13T10:00:00Z")
        expect(UsageEventLog.isExpired(fileName: "2025-06.jsonl", now: now),
               "13-month-old file is expired")
        expect(!UsageEventLog.isExpired(fileName: "2025-08.jsonl", now: now),
               "11-month-old file is kept")
        expect(!UsageEventLog.isExpired(fileName: "garbage.txt", now: now),
               "non-jsonl name is never expired")
        expect(!UsageEventLog.isExpired(fileName: "2025-13.jsonl", now: now),
               "invalid month is never expired")

        // --- 行エンコード（スキーマ v1・ソート済みキー・改行終端） ---
        let line = UsageEventLog.encodeLine(event: .tabOpen, meta: ["tab": "skills"],
                                            date: date("2026-07-13T10:00:00Z"))!
        let text = String(data: line, encoding: .utf8)!
        expect(text.hasSuffix("\n"), "encoded line ends with newline")
        let obj = try JSONSerialization.jsonObject(
            with: line.dropLast()) as! [String: Any]
        expect(obj["v"] as? Int == 1, "schema version is 1")
        expect(obj["event"] as? String == "tab_open", "event name encoded")
        expect((obj["meta"] as? [String: String])?["tab"] == "skills", "meta encoded")
        expect(ISO8601DateFormatter().date(from: obj["ts"] as! String) != nil,
               "ts is ISO8601")

        // --- 集計（期間フィルタ・壊れた行の無視） ---
        let jsonl = """
        {"event":"tab_open","meta":{"tab":"cost"},"ts":"2026-07-10T00:00:00Z","v":1}
        {"event":"tab_open","meta":{"tab":"skills"},"ts":"2026-06-01T00:00:00Z","v":1}
        {"event":"popover_open","meta":{},"ts":"2026-07-11T00:00:00Z","v":1}
        broken line
        """
        expect(UsageEventLog.countMatches(in: jsonl, event: .tabOpen,
                                          since: date("2026-07-01T00:00:00Z")) == 1,
               "countMatches filters by event and date, skips broken lines")

        // --- 書き込み → 読み出しの往復（一時ディレクトリ） ---
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-test-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "tokfuel-test")!
        suite.removePersistentDomain(forName: "tokfuel-test")
        let log = UsageEventLog(directory: dir, defaults: suite)
        log.log(.popoverOpen)
        log.log(.tabOpen, meta: ["tab": "tools"])
        expect(log.frequency(of: .tabOpen, days: 1) == 1, "frequency counts written event")
        expect(log.frequency(of: .popoverOpen, days: 1) == 1, "second event counted")

        // 無効化すると書かれない
        suite.set(false, forKey: UsageEventLog.enabledKey)
        log.log(.tabOpen, meta: ["tab": "tools"])
        expect(log.frequency(of: .tabOpen, days: 1) == 1, "disabled log writes nothing")

        // 全削除
        log.deleteAll()
        expect(log.frequency(of: .tabOpen, days: 1) == 0, "deleteAll clears events")
        try? FileManager.default.removeItem(at: dir)

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all tests passed")
    }
}
