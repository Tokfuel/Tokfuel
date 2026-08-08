import Foundation
import Testing

/// IT-F010-LC01 — E2E ランナーが期待する画面名の契約。
struct E2ESmokeContractTests {
    @Test func 期待画面一覧に主要画面が含まれる() throws {
        let url = Self.expectedScreensURL()
        let text = try String(contentsOf: url, encoding: .utf8)
        let names = text.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "#", maxSplits: 1)[0] }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for required in ["popover", "settings", "about", "budget-alert", "analytics-consent"] {
            #expect(names.contains(required), "missing \(required) in expected-screens.txt")
        }
        #expect(names.count >= 10)
    }

    private static func expectedScreensURL() -> URL {
        // App/Tests/<file> → App/E2E/expected-screens.txt
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("E2E/expected-screens.txt")
    }
}
