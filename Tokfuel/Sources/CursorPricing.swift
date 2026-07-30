import Foundation

/// Cursor の bubble はトークン数だけを持ち、金額を持たない。ここで $/MTok を掛けて金額化する。
///
/// 数値は Cursor 公式の価格表（<https://cursor.com/docs/models-and-pricing>、2026-07-30 時点）
/// から転記。Claude ファミリーの単価は同梱 retok（`Resources/retok.py` の `PRICING`）とも一致する
/// ので、アプリ内で同じモデル=同じ単価になっている。Cursor の価格改定のたびに手動更新が要る
/// （#5 の retok 価格表と同じ性質の負債）。
///
/// バリエーション（例: 拡張コンテキストの "1M" 版、"fast mode"）は基本ファミリーの単価に
/// まとめている——bubble からは正確な API モデル ID が取れないため、部分一致でしか判別できず、
/// 個別単価まで作り込む精度は無い。表にない/読み取れないモデルは合算せず 0 を返す
/// （「下限の推定値」という前提を崩さないための意図的な選択 — それらしい平均単価を捏造しない）。
enum CursorPricing {
    private struct Rate {
        let input: Double   // $ / 1M input tokens
        let output: Double  // $ / 1M output tokens
    }

    /// Claude（Anthropic）ファミリー: モデル ID に鍵の文字列が含まれるかで判定
    /// （retok の model_family と同じ手法）。表記ゆれ（Sonnet 4 / 4.5 / 4.6 など）は
    /// 単価が全バリエーションで一致するため、ファミリー名だけで十分。
    private static let claudeFamilies: [(key: String, rate: Rate)] = [
        ("fable",  Rate(input: 10.0, output: 50.0)),
        ("mythos", Rate(input: 10.0, output: 50.0)),   // Cursor の一覧には無いが Fable と同額
        ("opus",   Rate(input: 5.0,  output: 25.0)),
        ("sonnet", Rate(input: 3.0,  output: 15.0)),
        ("haiku",  Rate(input: 1.0,  output: 5.0))
    ]

    /// Claude 以外のファミリー: モデル ID の前方一致で判定。長い/より具体的なプレフィックスを
    /// 先に置く（例: "gpt-5.1-codex-max" が "gpt-5.1" より先にマッチする必要がある）。
    /// プロバイダごとにブロックを分けているが、プレフィックスの名前空間が重ならないので
    /// 検索は 1 本のリストで行う。
    private static let otherFamilies: [(prefix: String, rate: Rate)] = [
        // OpenAI (GPT-5.x)
        ("gpt-5.6-luna",       Rate(input: 1.0,  output: 6.0)),
        ("gpt-5.6-sol",        Rate(input: 5.0,  output: 30.0)),
        ("gpt-5.6-terra",      Rate(input: 2.5,  output: 15.0)),
        ("gpt-5.5",            Rate(input: 5.0,  output: 30.0)),
        ("gpt-5.4-mini",       Rate(input: 0.75, output: 4.5)),
        ("gpt-5.4-nano",       Rate(input: 0.2,  output: 1.25)),
        ("gpt-5.4",            Rate(input: 2.5,  output: 15.0)),
        ("gpt-5.3-codex",      Rate(input: 1.75, output: 14.0)),
        ("gpt-5.2-codex",      Rate(input: 1.75, output: 14.0)),
        ("gpt-5.2",            Rate(input: 1.75, output: 14.0)),
        ("gpt-5.1-codex-max",  Rate(input: 1.25, output: 10.0)),
        ("gpt-5.1-codex-mini", Rate(input: 0.25, output: 2.0)),
        ("gpt-5.1-codex",      Rate(input: 1.25, output: 10.0)),
        ("gpt-5.1",            Rate(input: 1.25, output: 10.0)),
        ("gpt-5-fast",         Rate(input: 2.5,  output: 20.0)),
        ("gpt-5-mini",         Rate(input: 0.25, output: 2.0)),
        ("gpt-5-codex",        Rate(input: 1.25, output: 10.0)),
        ("gpt-5-nano",         Rate(input: 0.05, output: 0.4)),
        ("gpt-5",              Rate(input: 1.25, output: 10.0)),
        // Google (Gemini)
        ("gemini-2.5-flash",   Rate(input: 0.3,  output: 2.5)),
        ("gemini-3-pro-image", Rate(input: 2.0,  output: 12.0)),   // 画像出力の別課金は反映できない
        ("gemini-3-flash",     Rate(input: 0.5,  output: 3.0)),
        ("gemini-3-pro",       Rate(input: 2.0,  output: 12.0)),
        ("gemini-3.1-pro",     Rate(input: 2.0,  output: 12.0)),
        ("gemini-3.5-flash",   Rate(input: 1.5,  output: 9.0)),
        ("gemini-3.6-flash",   Rate(input: 1.5,  output: 7.5)),
        // Z.ai (GLM)
        ("glm-5.2",            Rate(input: 1.4,  output: 4.4)),
        // Moonshot (Kimi)
        ("kimi-k2.7-code",     Rate(input: 0.95, output: 4.0)),
        ("kimi-k3",            Rate(input: 3.0,  output: 15.0))
    ]

    private static func rate(for modelID: String) -> Rate? {
        let lower = modelID.lowercased()
        if let match = claudeFamilies.first(where: { lower.contains($0.key) }) {
            return match.rate
        }
        // Cursor 公式ページから当日取得できていれば、そちらが otherFamilies より優先。
        // CursorPricingService.cachedRates() はキー長の降順で並んでいるので、そのまま
        // hasPrefix で探せば otherFamilies と同じ「具体的な方が先にマッチ」が成り立つ。
        if let cached = CursorPricingService.cachedRates()
            .first(where: { lower.hasPrefix($0.key) }) {
            return Rate(input: cached.input, output: cached.output)
        }
        if let match = otherFamilies.first(where: { lower.hasPrefix($0.prefix) }) {
            return match.rate
        }
        return nil
    }

    /// モデルが不明なら 0（合算しない）。
    static func cost(modelID: String?, inputTokens: Int, outputTokens: Int) -> Double {
        guard let modelID, let rate = rate(for: modelID) else { return 0 }
        return (Double(inputTokens) * rate.input + Double(outputTokens) * rate.output) / 1_000_000
    }
}
