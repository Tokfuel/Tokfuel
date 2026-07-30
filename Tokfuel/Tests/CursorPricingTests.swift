import Foundation
import Testing
@testable import Tokfuel

/// CursorPricing はハードコードした単価表を持たない — CursorPricingService のキャッシュだけを
/// 見る。テストは全て同じ UserDefaults キーを共有するキャッシュを触るので、他のテスト（この
/// ファイル・CursorCostDriverTests.swift の両方）と並行に走っても衝突しないよう、各テストは
/// 自分専用のキー名（"unittest-cursorpricing-" 接頭辞）だけを足し引きする
/// （setCachedRatesForTesting は丸ごと置き換えず差分マージなので、他のテストが積んだキーは
/// 壊さない）。
struct CursorPricingTests {
    private func rate(_ key: String, input: Double, output: Double) -> CursorPricingService.CachedRate {
        CursorPricingService.CachedRate(key: key, input: input, output: output)
    }

    private func withCache(_ rates: [CursorPricingService.CachedRate], _ body: () -> Void) {
        CursorPricingService.setCachedRatesForTesting(rates)
        defer { CursorPricingService.removeCachedRatesForTesting(keys: rates.map(\.key)) }
        body()
    }

    private static let prefix = "unittest-cursorpricing-"

    @Test func キャッシュにあるモデルは単価を引ける() {
        let key = Self.prefix + "claude-4-5-sonnet"
        withCache([rate(key, input: 3.0, output: 15.0)]) {
            #expect(CursorPricing.cost(modelID: key, inputTokens: 1_000_000, outputTokens: 0) == 3.0)
        }
    }

    @Test func 前方一致で引ける() {
        let key = Self.prefix + "gpt-5.1-codex-max"
        withCache([rate(key, input: 1.25, output: 10.0)]) {
            // 実際のモデル ID にはサフィックス（日付・variant 等）が付くことがある想定。
            #expect(CursorPricing.cost(modelID: key + "-preview",
                                       inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        }
    }

    @Test func より長いキーが先にマッチする() {
        // 長い方 (codex-max) が短い方 (無印) のプレフィックスでもある。
        let longKey = Self.prefix + "gpt-5.1-codex-max"
        let shortKey = Self.prefix + "gpt-5.1"
        withCache([
            rate(longKey, input: 1.25, output: 10.0),
            rate(shortKey, input: 999.0, output: 999.0)   // マッチしたら一目で分かる値
        ]) {
            #expect(CursorPricing.cost(modelID: longKey,
                                       inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        }
    }

    @Test func 未登録のモデルは0() {
        // UUID を混ぜて、他のどのテストも束の間でも登録し得ないキーにする
        // ——「キャッシュが空」を仮定せず「このキーは無い」だけを仮定する。
        let neverSeeded = "unittest-cursorpricing-never-\(UUID().uuidString)"
        #expect(CursorPricing.cost(modelID: neverSeeded,
                                   inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
    }

    @Test func キャッシュにあってもモデルが見つからなければ0() {
        let key = Self.prefix + "claude-4-5-sonnet-2"
        let other = "unittest-cursorpricing-unrelated-\(UUID().uuidString)"
        withCache([rate(key, input: 3.0, output: 15.0)]) {
            #expect(CursorPricing.cost(modelID: other,
                                       inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
        }
    }

    @Test func modelIDがnilなら0() {
        #expect(CursorPricing.cost(modelID: nil, inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
    }

    @Test func 入力と出力の両方が単価に反映される() {
        let key = Self.prefix + "claude-4-5-sonnet-3"
        withCache([rate(key, input: 3.0, output: 15.0)]) {
            let cost = CursorPricing.cost(modelID: key, inputTokens: 1_000_000, outputTokens: 500_000)
            #expect(cost == 3.0 + 7.5)
        }
    }
}
