import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
@testable import Tokfuel

struct UsageEventLogTests {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    @Test func 月別ファイル名と保持期間を判定する() {
        let now = date("2026-07-13T10:00:00Z")
        #expect(UsageEventLog.fileName(for: now) == "2026-07.jsonl")
        #expect(UsageEventLog.isExpired(fileName: "2025-06.jsonl", now: now))
        #expect(!UsageEventLog.isExpired(fileName: "2025-08.jsonl", now: now))
        #expect(!UsageEventLog.isExpired(fileName: "garbage.txt", now: now))
    }

    @Test func イベントを改行終端のJSONとして符号化する() throws {
        let line = try #require(UsageEventLog.encodeLine(
            event: .tabOpen,
            meta: ["tab": "cost"],
            date: date("2026-07-13T10:00:00Z")
        ))
        #expect(line.last == 0x0A)
        let object = try #require(
            JSONSerialization.jsonObject(with: line.dropLast()) as? [String: Any]
        )
        #expect(object["v"] as? Int == 1)
        #expect(object["event"] as? String == "tab_open")
    }
}
