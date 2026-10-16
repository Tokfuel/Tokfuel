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

struct RetokServiceTests {
    private func localesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokfuel-locales-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #"{"no_transcripts": "対象期間にトランスクリプトが見つかりませんでした。"}"#
            .write(to: dir.appendingPathComponent("ja.json"), atomically: true, encoding: .utf8)
        return dir
    }

    @Test func ロケール済みの0件メッセージは空として扱う() throws {
        let dir = try localesDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(RetokService.isNoTranscriptsMessage(
            "対象期間にトランスクリプトが見つかりませんでした。\n", localesDir: dir))
    }

    @Test func 英語の既定メッセージはロケールが読めなくても空として扱う() {
        #expect(RetokService.isNoTranscriptsMessage(
            "No transcripts found in the selected period.", localesDir: nil))
    }

    @Test func 本当の失敗は空として扱わない() throws {
        let dir = try localesDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(!RetokService.isNoTranscriptsMessage("Traceback (most recent call last):", localesDir: dir))
        #expect(!RetokService.isNoTranscriptsMessage("", localesDir: dir))
    }

    @Test func 空レポートは全てゼロで期間を保つ() {
        let report = RetokReport.empty(periodDays: 30)
        #expect(report.periodDays == 30)
        #expect(report.totals.cost == 0)
        #expect(report.daily.isEmpty && report.perModel.isEmpty && report.topSessions.isEmpty)
    }
}
