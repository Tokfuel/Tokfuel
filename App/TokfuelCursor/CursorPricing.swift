import Foundation
import TokfuelCore

/// 単価はハードコードしない——`CursorPricingService` のキャッシュだけを参照する。
/// キャッシュが無い、またはモデルが表に無ければ 0（それらしい単価を捏造しない）。
public enum CursorPricing {
    private static func rate(for modelID: String) -> (input: Double, output: Double)? {
        let lower = modelID.lowercased()
        // cachedRates() はキー長の降順で並んでいるので、hasPrefix で探すだけで
        // 「より具体的なモデル名が先にマッチする」が自然に成り立つ。
        guard let cached = CursorPricingService.cachedRates()
            .first(where: { lower.hasPrefix($0.key) })
        else { return nil }
        return (cached.input, cached.output)
    }

    /// モデルが不明、またはまだ価格表を取得できていなければ 0（合算しない）。
    public static func cost(modelID: String?, inputTokens: Int, outputTokens: Int) -> Double {
        guard let modelID, let rate = rate(for: modelID) else { return 0 }
        return (Double(inputTokens) * rate.input + Double(outputTokens) * rate.output) / 1_000_000
    }
}
