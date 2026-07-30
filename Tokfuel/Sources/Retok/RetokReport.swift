import Foundation

/// コスト分析レポート（retok --json と同じ形）。コスト・トークン・キャッシュ効率・推奨事項を保持する。
/// 生成は RetokAnalyzer（retok.py のネイティブ移植）。Decodable はテスト・将来のキャッシュ用に残す。
struct RetokReport: Decodable, Sendable {
    struct Totals: Decodable, Sendable {
        var cost: Double = 0
        var input: Int = 0
        var output: Int = 0
        var cacheRead: Int = 0
        var cacheWrite: Int = 0
        var prompts: Int = 0
        var requests: Int = 0

        enum CodingKeys: String, CodingKey {
            case cost, input, output, prompts, requests
            case cacheRead = "cache_read"
            case cacheWrite = "cache_write"
        }
    }

    struct ModelUsage: Decodable, Sendable {
        var cost: Double = 0
        var input: Int = 0
        var output: Int = 0
        var requests: Int = 0
    }

    struct DailyCost: Decodable, Sendable {
        var cost: Double = 0
        var output: Int = 0
    }

    struct Advice: Decodable, Identifiable, Sendable {
        let severity: String   // "high" / "info" など
        let key: String
        let title: String
        let detail: String
        var id: String { key }
    }

    struct TopSession: Decodable, Identifiable, Sendable {
        let session: String
        let project: String
        let cost: Double
        let prompts: Int
        let maxContext: Int
        var id: String { session }

        enum CodingKeys: String, CodingKey {
            case session, project, cost, prompts
            case maxContext = "max_context"
        }
    }

    let periodDays: Int
    let filesScanned: Int
    let totals: Totals
    let cacheHitRate: Double
    let perModel: [String: ModelUsage]
    let daily: [String: DailyCost]
    let advice: [Advice]
    let topSessions: [TopSession]

    enum CodingKeys: String, CodingKey {
        case totals, daily, advice
        case periodDays = "period_days"
        case filesScanned = "files_scanned"
        case cacheHitRate = "cache_hit_rate"
        case perModel = "per_model"
        case topSessions = "top_sessions"
    }

    /// 日付昇順の (date, cost) 列。グラフ用。
    var dailySorted: [(date: String, cost: Double)] {
        daily.map { (date: $0.key, cost: $0.value.cost) }.sorted { $0.date < $1.date }
    }

    /// コスト降順のモデル別内訳。
    var modelsSorted: [(model: String, usage: ModelUsage)] {
        perModel.map { (model: $0.key, usage: $0.value) }.sorted { $0.usage.cost > $1.usage.cost }
    }

    func cost(on date: String) -> Double? { daily[date]?.cost }
}

