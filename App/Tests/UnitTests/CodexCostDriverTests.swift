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

@Suite struct CodexCostDriverTests {
    private static func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    @Test func daysNeededはfromを含む日数を返す() {
        #expect(CodexCostDriver.daysNeeded(from: "2026-07-01", reference: Self.date("2026-07-01")) == 1)
        #expect(CodexCostDriver.daysNeeded(from: "2026-07-01", reference: Self.date("2026-07-08")) == 8)
    }

    @Test func daysNeededは最低1日を返す() {
        #expect(CodexCostDriver.daysNeeded(from: "2026-07-10", reference: Self.date("2026-07-01")) == 1)
    }

    @Test func daysNeededはパース不能ならnil() {
        #expect(CodexCostDriver.daysNeeded(from: "not-a-date", reference: Date()) == nil)
    }

    @Test func idと表示名() {
        let driver = CodexCostDriver()
        #expect(driver.id == "codex")
        #expect(driver.displayName == "Codex")
    }
}
