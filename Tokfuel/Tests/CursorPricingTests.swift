import Testing
@testable import Tokfuel

/// CursorPricing の単価表はプレフィックスの並び順に依存する（"gpt-5.1-codex-max" が
/// "gpt-5.1" より先にマッチしないと壊れる)。ここでは主に、その順序が壊れやすい境界だけを狙う。
struct CursorPricingTests {
    @Test func Claudeファミリーは表記ゆれを問わず同じ単価() {
        #expect(CursorPricing.cost(modelID: "claude-4-5-sonnet", inputTokens: 1_000_000, outputTokens: 0) == 3.0)
        #expect(CursorPricing.cost(modelID: "claude-4-6-sonnet-thinking", inputTokens: 1_000_000, outputTokens: 0) == 3.0)
        #expect(CursorPricing.cost(modelID: "claude-opus-4-8", inputTokens: 1_000_000, outputTokens: 0) == 5.0)
        #expect(CursorPricing.cost(modelID: "claude-4-5-haiku", inputTokens: 1_000_000, outputTokens: 0) == 1.0)
    }

    @Test func gpt5系はより具体的なプレフィックスが優先される() {
        // "gpt-5.1-codex-max" は "gpt-5.1" のプレフィックスでもあるため、順序を間違えると
        // 汎用の gpt-5.1 単価（1.25）に落ちてしまう。
        #expect(CursorPricing.cost(modelID: "gpt-5.1-codex-max", inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        #expect(CursorPricing.cost(modelID: "gpt-5.1-codex-mini", inputTokens: 1_000_000, outputTokens: 0) == 0.25)
        #expect(CursorPricing.cost(modelID: "gpt-5.1", inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        // "gpt-5.4-mini" / "gpt-5.4-nano" は "gpt-5.4" のプレフィックスでもある。
        #expect(CursorPricing.cost(modelID: "gpt-5.4-mini", inputTokens: 1_000_000, outputTokens: 0) == 0.75)
        #expect(CursorPricing.cost(modelID: "gpt-5.4-nano", inputTokens: 1_000_000, outputTokens: 0) == 0.2)
        #expect(CursorPricing.cost(modelID: "gpt-5.4", inputTokens: 1_000_000, outputTokens: 0) == 2.5)
        // "gpt-5-mini" / "gpt-5-codex" / "gpt-5-nano" / "gpt-5-fast" は "gpt-5" のプレフィックスでもある。
        #expect(CursorPricing.cost(modelID: "gpt-5-mini", inputTokens: 1_000_000, outputTokens: 0) == 0.25)
        #expect(CursorPricing.cost(modelID: "gpt-5-codex", inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        #expect(CursorPricing.cost(modelID: "gpt-5", inputTokens: 1_000_000, outputTokens: 0) == 1.25)
    }

    @Test func geminiの画像プレビューは通常のproより先にマッチする() {
        // "gemini-3-pro-image-preview" は "gemini-3-pro" のプレフィックスでもある。
        #expect(CursorPricing.cost(modelID: "gemini-3-pro-image-preview", inputTokens: 1_000_000, outputTokens: 0) == 2.0)
        #expect(CursorPricing.cost(modelID: "gemini-3-pro", inputTokens: 1_000_000, outputTokens: 0) == 2.0)
        #expect(CursorPricing.cost(modelID: "gemini-3.1-pro", inputTokens: 1_000_000, outputTokens: 0) == 2.0)
        #expect(CursorPricing.cost(modelID: "gemini-3-flash", inputTokens: 1_000_000, outputTokens: 0) == 0.5)
        #expect(CursorPricing.cost(modelID: "gemini-3.5-flash", inputTokens: 1_000_000, outputTokens: 0) == 1.5)
    }

    @Test func GLMとKimiも認識する() {
        #expect(CursorPricing.cost(modelID: "glm-5.2", inputTokens: 1_000_000, outputTokens: 0) == 1.4)
        #expect(CursorPricing.cost(modelID: "kimi-k3", inputTokens: 1_000_000, outputTokens: 0) == 3.0)
        #expect(CursorPricing.cost(modelID: "kimi-k2.7-code", inputTokens: 1_000_000, outputTokens: 0) == 0.95)
    }

    @Test func 未知のモデルは0() {
        #expect(CursorPricing.cost(modelID: "some-brand-new-model", inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
        #expect(CursorPricing.cost(modelID: nil, inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
    }

    @Test func 入力と出力の両方が単価に反映される() {
        let cost = CursorPricing.cost(modelID: "claude-4-5-sonnet", inputTokens: 1_000_000, outputTokens: 500_000)
        #expect(cost == 3.0 + 7.5)
    }
}
