import Foundation
import Testing
@testable import Tokfuel

struct MoneyFormattingTests {
    @Test func 百ドル未満はセント2桁() {
        #expect(PopoverView.money(0) == "$0.00")
        #expect(PopoverView.money(0.05) == "$0.05")
        #expect(PopoverView.money(99.99) == "$99.99")
    }

    @Test func 百ドル以上は整数表示() {
        #expect(PopoverView.money(100) == "$100")
        #expect(PopoverView.money(1234.56) == "$1235")
    }
}

struct MenuBarDisplayTests {
    @Test func 月表示を含む選択肢だけが月間集計を要求する() {
        #expect(MenuBarDisplay.monthlyCost.showsMonthlyCost)
        #expect(MenuBarDisplay.bothCosts.showsMonthlyCost)
        #expect(!MenuBarDisplay.cost.showsMonthlyCost)
        #expect(!MenuBarDisplay.prompts.showsMonthlyCost)
        #expect(!MenuBarDisplay.iconOnly.showsMonthlyCost)
    }

    @Test func 保存済みrawValueは変えない() {
        // UserDefaults に永続化されるため、rawValue の変更は既存ユーザーの設定を壊す。
        #expect(MenuBarDisplay(rawValue: "cost") == .cost)
        #expect(MenuBarDisplay(rawValue: "monthlyCost") == .monthlyCost)
        #expect(MenuBarDisplay(rawValue: "bothCosts") == .bothCosts)
        #expect(MenuBarDisplay(rawValue: "prompts") == .prompts)
        #expect(MenuBarDisplay(rawValue: "iconOnly") == .iconOnly)
    }
}
