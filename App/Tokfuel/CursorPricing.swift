import Foundation

/// Cursor の bubble はトークン数だけを持ち、金額を持たない。ここで $/MTok を掛けて金額化する。
///
/// 単価はハードコードしない——`CursorPricingService` が Cursor 公式の価格表
/// （<https://cursor.com/docs/models-and-pricing>）から毎日取得したキャッシュだけを参照する。
/// キャッシュがまだ無い（初回起動・オフライン等）、またはモデルがキャッシュに無ければ 0 を返す
/// （「下限の推定値」という前提を崩さないための意図的な選択 — それらしい単価を捏造しない）。
enum CursorPricing {
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
    static func cost(modelID: String?, inputTokens: Int, outputTokens: Int) -> Double {
        guard let modelID, let rate = rate(for: modelID) else { return 0 }
        return (Double(inputTokens) * rate.input + Double(outputTokens) * rate.output) / 1_000_000
    }
}
