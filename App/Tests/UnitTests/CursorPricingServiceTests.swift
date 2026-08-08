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

/// cursor.com のドキュメントページは API ではないので、パーサーはページの見た目の変化に
/// 弱くならないよう防御的でなければならない。ここでは実ページの抜粋（2026-07-30 時点）と、
/// 崩れた行の両方に対する振る舞いを確認する。ネットワーク自体は叩かない（parseTable は
/// 純粋関数）。
struct CursorPricingServiceTests {
    private let sample = """
    # Models & Pricing

    | Model | Provider | Input | Cache write | Cache read | Output | Notes |
    | --------------------------------------------------------------------------------------------- | --------- | ----- | ----------- | ---------- | ------ | ------- |
    | [Claude 4.5 Sonnet](https://www.anthropic.com/claude/sonnet) | Anthropic | $3 | $3.75 | $0.3 | $15 | Hidden by default |
    | [GPT-5.1 Codex Max](https://platform.openai.com/docs/models/gpt-5-codex) | OpenAI | $1.25 | - | $0.125 | $10 | Hidden by default |
    | [GPT-5.1 Codex](https://platform.openai.com/docs/models/gpt-5-codex) | OpenAI | $1.25 | - | $0.125 | $10 | Hidden by default |
    | [Claude Opus 4.7 (fast mode)](https://www.anthropic.com/claude/opus) | Anthropic | $30 | $37.5 | $3 | $150 | Limited research preview |
    | 見出しでも区切りでもない本文の段落。 |
    | not a price row | Provider | Input | - | - | - | Notes |
    """

    @Test func 実ページ抜粋を正しくパースする() {
        let rates = CursorPricingService.parseTable(sample)
        let gptCodexMax = rates.first { $0.key == "gpt-5.1-codex-max" }
        #expect(gptCodexMax?.input == 1.25)
        #expect(gptCodexMax?.output == 10.0)

        let sonnet = rates.first { $0.key == "claude-4.5-sonnet" }
        #expect(sonnet?.input == 3.0)
        #expect(sonnet?.output == 15.0)
    }

    @Test func 括弧の注記は末尾から落としてキーにする() {
        let rates = CursorPricingService.parseTable(sample)
        let opusFast = rates.first { $0.key == "claude-opus-4.7" }
        #expect(opusFast?.input == 30.0)
        #expect(opusFast?.output == 150.0)
    }

    @Test func 見出し行と区切り行はキーとして現れない() {
        let rates = CursorPricingService.parseTable(sample)
        #expect(rates.contains { $0.key == "model" } == false)
        #expect(rates.allSatisfy { !$0.key.contains("---") })
    }

    @Test func 列が足りない行や価格が読めない行はスキップする() {
        let rates = CursorPricingService.parseTable(sample)
        // "not a price row" の Input 列は "Input" という文字列で $ が無いためスキップされる。
        #expect(rates.contains { $0.key == "not-a-price-row" } == false)
        // パイプで始まらない段落や、列が足りない行も無視される。
        #expect(rates.count == 4)
    }

    @Test func より長いキーが先に来るよう降順ソートされる() {
        let rates = CursorPricingService.parseTable(sample)
        for i in 1..<rates.count {
            #expect(rates[i - 1].key.count >= rates[i].key.count)
        }
        // "gpt-5.1-codex-max" は "gpt-5.1-codex" のプレフィックスでもあるので、
        // 具体的な方（長い方）が先に来ないと誤マッチする。
        let maxIndex = rates.firstIndex { $0.key == "gpt-5.1-codex-max" }
        let plainIndex = rates.firstIndex { $0.key == "gpt-5.1-codex" }
        #expect(maxIndex != nil && plainIndex != nil && maxIndex! < plainIndex!)
    }

    @Test func 壊れたテーブルでもクラッシュせず空を返す() {
        #expect(CursorPricingService.parseTable("").isEmpty)
        #expect(CursorPricingService.parseTable("no pipes here at all").isEmpty)
        #expect(CursorPricingService.parseTable("| only one cell").isEmpty)
    }
}
