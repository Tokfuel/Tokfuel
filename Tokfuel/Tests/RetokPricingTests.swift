import Foundation
import Testing
@testable import Tokfuel

/// 価格表とコスト式の手計算検証。期待値は retok.py の PRICING / entry_cost / codex_cost に基づく。
struct RetokPricingTests {

    @Test func モデルIDからファミリを部分一致で引ける() {
        #expect(RetokPricing.modelFamily("claude-fable-5") == "fable")
        #expect(RetokPricing.modelFamily("claude-sonnet-5") == "sonnet")
        #expect(RetokPricing.modelFamily("claude-haiku-4-5-20251001") == "haiku")
        #expect(RetokPricing.modelFamily("gpt-4") == nil)
        #expect(RetokPricing.modelFamily(nil) == nil)
        #expect(RetokPricing.modelFamily("") == nil)
    }

    @Test func 入出力トークンのコスト() {
        // sonnet: input $3/MTok, output $15/MTok
        let cost = RetokPricing.entryCost(modelID: "claude-sonnet-5", input: 1_000_000,
                                          output: 1_000_000, cacheRead: 0, write5m: 0, write1h: 0)
        #expect(abs(cost - 18.0) < 1e-9)
    }

    @Test func キャッシュ読出は入力単価の1割() {
        let cost = RetokPricing.entryCost(modelID: "claude-haiku-4-5", input: 0, output: 0,
                                          cacheRead: 1_000_000, write5m: 0, write1h: 0)
        #expect(abs(cost - 0.1) < 1e-9)
    }

    @Test func キャッシュ書込は5mが1_25倍で1hが2倍() {
        let w5m = RetokPricing.entryCost(modelID: "claude-opus-5", input: 0, output: 0,
                                         cacheRead: 0, write5m: 1_000_000, write1h: 0)
        #expect(abs(w5m - 6.25) < 1e-9)
        let w1h = RetokPricing.entryCost(modelID: "claude-opus-5", input: 0, output: 0,
                                         cacheRead: 0, write5m: 0, write1h: 1_000_000)
        #expect(abs(w1h - 10.0) < 1e-9)
    }

    @Test func 未知モデルはコスト0() {
        let cost = RetokPricing.entryCost(modelID: "unknown-model", input: 1_000_000,
                                          output: 1_000_000, cacheRead: 0, write5m: 0, write1h: 0)
        #expect(cost == 0)
    }

    @Test func OpenAI価格は最長プレフィックス一致() {
        // "gpt-5-nano" は "gpt-5" より先に一致しなければならない
        #expect(RetokPricing.openAIPrice("gpt-5-nano-2026")?.input == 0.05)
        #expect(RetokPricing.openAIPrice("gpt-5")?.input == 1.25)
        #expect(RetokPricing.openAIPrice("gpt-5.1-codex-max-high")?.input == 1.25)
        #expect(RetokPricing.openAIPrice("gpt-5.4")?.input == 2.5)
        #expect(RetokPricing.openAIPrice("o3") == nil)
    }

    @Test func Codexコストはキャッシュ入力を1割で計上() {
        // gpt-5.4: (600k*2.5 + 400k*2.5*0.1 + 100k*15) / 1e6 = 1.5 + 0.1 + 1.5
        let cost = RetokPricing.codexCost(modelID: "gpt-5.4", inputTotal: 1_000_000,
                                          cached: 400_000, output: 100_000)
        #expect(abs(cost - 3.1) < 1e-9)
        #expect(RetokPricing.codexCost(modelID: "unknown", inputTotal: 1_000_000,
                                       cached: 0, output: 0) == 0)
    }
}
