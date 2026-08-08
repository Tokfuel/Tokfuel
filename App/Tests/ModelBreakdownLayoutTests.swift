import CoreGraphics
import Testing
@testable import Tokfuel

/// IT-F001-DS01 / IT-F001-DS02
struct ModelBreakdownLayoutTests {
    @Test func 表示文字列はモデルID全文() {
        #expect(ModelBreakdownLayout.name("cursor-grok-4.5-high-fast")
                == "cursor-grok-4.5-high-fast")
        #expect(ModelBreakdownLayout.name("claude-haiku-4-5-20251001")
                == "claude-haiku-4-5-20251001")
    }

    @Test func 名前列は短い固定幅より広い() {
        #expect(ModelBreakdownLayout.nameMinWidth > 100)
    }

    @Test func 金額列は64ptの右寄せ幅() {
        #expect(ModelBreakdownLayout.moneyWidth == 64)
    }
}

/// IT-F001-DS03
@MainActor
struct ModelBreakdownFixtureTests {
    @Test func プレビューに長いCursorモデルIDが含まれる() {
        #expect(ScreenshotRenderer.cursorModelCosts.keys
            .contains("cursor-grok-4.5-high-fast"))
        let sum = ScreenshotRenderer.cursorModelCosts.values.reduce(0, +)
        #expect(abs(sum - ScreenshotRenderer.cursorTodayCost) < 0.0001)
    }
}
