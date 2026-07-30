import Foundation

/// retok.py の価格表とコスト式の移植。表は retok 上流（github.com/d-date/retok）に追随させるため
/// ここ 1 箇所に集約し、出典を明記する。
enum RetokPricing {
    struct Price: Sendable {
        let input: Double   // USD / MTok
        let output: Double  // USD / MTok
    }

    /// Claude の MTok 単価 (USD)。キャッシュ書込は input の 1.25x (5m TTL) / 2x (1h TTL)、
    /// キャッシュ読出は 0.1x。出典: platform.claude.com (2026-06)、retok.py PRICING と同一。
    /// モデル ID への部分一致で先勝ちするため、順序を retok と揃えている。
    static let claude: [(family: String, price: Price)] = [
        ("fable",  Price(input: 10.0, output: 50.0)),
        ("mythos", Price(input: 10.0, output: 50.0)),
        ("opus",   Price(input: 5.0,  output: 25.0)),
        ("sonnet", Price(input: 3.0,  output: 15.0)),
        ("haiku",  Price(input: 1.0,  output: 5.0)),
    ]
    static let cacheWrite5m = 1.25
    static let cacheWrite1h = 2.0
    static let cacheRead = 0.1

    /// OpenAI (Codex) の MTok 単価 (USD)。最長プレフィックス一致になるよう長い順に並べてある。
    /// キャッシュ入力は input の 0.1x、書込プレミアムなし。出典: developers.openai.com (2026-07)。
    static let openAI: [(prefix: String, price: Price)] = [
        ("gpt-5.5",           Price(input: 5.0,  output: 30.0)),
        ("gpt-5.4",           Price(input: 2.5,  output: 15.0)),
        ("gpt-5.3",           Price(input: 1.75, output: 14.0)),
        ("gpt-5.2",           Price(input: 1.75, output: 14.0)),
        ("gpt-5.1-codex-max", Price(input: 1.25, output: 10.0)),
        ("gpt-5.1",           Price(input: 1.25, output: 10.0)),
        ("gpt-5-mini",        Price(input: 0.25, output: 2.0)),
        ("gpt-5-nano",        Price(input: 0.05, output: 0.4)),
        ("gpt-5",             Price(input: 1.25, output: 10.0)),
    ]
    static let openAICacheRead = 0.1

    /// ephemeral 5m キャッシュの TTL（TTL 失効ヒューリスティック用）。
    static let cacheTTLSeconds: TimeInterval = 5 * 60

    /// モデル ID から価格ファミリを引く（retok の model_family と同じ部分一致）。
    static func modelFamily(_ modelID: String?) -> String? {
        guard let modelID, !modelID.isEmpty else { return nil }
        return claude.first { modelID.contains($0.family) }?.family
    }

    static func price(family: String) -> Price? {
        claude.first { $0.family == family }?.price
    }

    static func openAIPrice(_ modelID: String?) -> Price? {
        guard let modelID, !modelID.isEmpty else { return nil }
        return openAI.first { modelID.hasPrefix($0.prefix) }?.price
    }

    /// Claude API 1 リクエスト分のコスト (USD)。write5m/write1h は呼び出し側で
    /// cache_creation の内訳（無ければ全量 5m 扱い）に振り分けてから渡す。
    static func entryCost(modelID: String?, input: Int, output: Int,
                          cacheRead read: Int, write5m: Int, write1h: Int) -> Double {
        guard let family = modelFamily(modelID), let p = price(family: family) else { return 0 }
        let cost = Double(input) * p.input
            + Double(output) * p.output
            + Double(read) * p.input * cacheRead
            + Double(write5m) * p.input * cacheWrite5m
            + Double(write1h) * p.input * cacheWrite1h
        return cost / 1_000_000
    }

    /// Codex 1 リクエスト分のコスト (USD)。cached は inputTotal の内数。
    static func codexCost(modelID: String, inputTotal: Int, cached: Int, output: Int) -> Double {
        guard let p = openAIPrice(modelID) else { return 0 }
        return (Double(inputTotal - cached) * p.input
            + Double(cached) * p.input * openAICacheRead
            + Double(output) * p.output) / 1_000_000
    }
}
