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

/// CursorPricing はハードコードした単価表を持たない — CursorPricingService のキャッシュだけを
/// 見る。テストは同じ UserDefaults キーを共有するので、各テストは自分専用のキー名
/// （"unittest-cursorpricing-" 接頭辞）だけを足し引きする（差分マージなので他テストのキーは壊さない）。
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
            #expect(CursorPricing.cost(modelID: key + "-preview",
                                       inputTokens: 1_000_000, outputTokens: 0) == 1.25)
        }
    }

    @Test func より長いキーが先にマッチする() {
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
        // setCachedRatesForTesting を呼ばない——「キャッシュが空」ではなく「このキーは無い」だけを仮定する。
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
