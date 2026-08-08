import Foundation

/// retok --json の出力。コスト・トークン・キャッシュ効率・推奨事項を保持する。
public struct RetokReport: Codable, Sendable {
    public struct Totals: Codable, Sendable {
        public var cost: Double = 0
        public var input: Int = 0
        public var output: Int = 0
        public var cacheRead: Int = 0
        public var cacheWrite: Int = 0
        public var prompts: Int = 0
        public var requests: Int = 0

        public init(cost: Double = 0, input: Int = 0, output: Int = 0,
                    cacheRead: Int = 0, cacheWrite: Int = 0, prompts: Int = 0, requests: Int = 0) {
            self.cost = cost
            self.input = input
            self.output = output
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
            self.prompts = prompts
            self.requests = requests
        }

        enum CodingKeys: String, CodingKey {
            case cost, input, output, prompts, requests
            case cacheRead = "cache_read"
            case cacheWrite = "cache_write"
        }
    }

    public struct ModelUsage: Codable, Sendable {
        public var cost: Double = 0
        public var input: Int = 0
        public var output: Int = 0
        public var requests: Int = 0

        public init(cost: Double = 0, input: Int = 0, output: Int = 0, requests: Int = 0) {
            self.cost = cost
            self.input = input
            self.output = output
            self.requests = requests
        }
    }

    public struct DailyCost: Codable, Sendable {
        public var cost: Double = 0
        public var output: Int = 0

        public init(cost: Double = 0, output: Int = 0) {
            self.cost = cost
            self.output = output
        }
    }

    public struct Advice: Codable, Identifiable, Sendable {
        public let severity: String
        public let key: String
        public let title: String
        public let detail: String
        public var id: String { key }

        public init(severity: String, key: String, title: String, detail: String) {
            self.severity = severity
            self.key = key
            self.title = title
            self.detail = detail
        }
    }

    public struct TopSession: Codable, Identifiable, Sendable {
        public let session: String
        public let project: String
        public let cost: Double
        public let prompts: Int
        public let maxContext: Int
        public var id: String { session }

        public init(session: String, project: String, cost: Double, prompts: Int, maxContext: Int) {
            self.session = session
            self.project = project
            self.cost = cost
            self.prompts = prompts
            self.maxContext = maxContext
        }

        enum CodingKeys: String, CodingKey {
            case session, project, cost, prompts
            case maxContext = "max_context"
        }
    }

    public let periodDays: Int
    public let filesScanned: Int
    public let totals: Totals
    public let cacheHitRate: Double
    public let perModel: [String: ModelUsage]
    public let daily: [String: DailyCost]
    public let advice: [Advice]
    public let topSessions: [TopSession]

    public init(periodDays: Int, filesScanned: Int, totals: Totals, cacheHitRate: Double,
                perModel: [String: ModelUsage], daily: [String: DailyCost], advice: [Advice],
                topSessions: [TopSession]) {
        self.periodDays = periodDays
        self.filesScanned = filesScanned
        self.totals = totals
        self.cacheHitRate = cacheHitRate
        self.perModel = perModel
        self.daily = daily
        self.advice = advice
        self.topSessions = topSessions
    }

    enum CodingKeys: String, CodingKey {
        case totals, daily, advice
        case periodDays = "period_days"
        case filesScanned = "files_scanned"
        case cacheHitRate = "cache_hit_rate"
        case perModel = "per_model"
        case topSessions = "top_sessions"
    }

    public var dailySorted: [(date: String, cost: Double)] {
        daily.map { (date: $0.key, cost: $0.value.cost) }.sorted { $0.date < $1.date }
    }

    public var modelsSorted: [(model: String, usage: ModelUsage)] {
        perModel.map { (model: $0.key, usage: $0.value) }.sorted { $0.usage.cost > $1.usage.cost }
    }

    public func cost(on date: String) -> Double? { daily[date]?.cost }

    public func merging(daily other: [String: DailyCost]) -> RetokReport {
        var merged = daily
        for (date, value) in other { merged[date] = value }
        return RetokReport(periodDays: periodDays, filesScanned: filesScanned, totals: totals,
                           cacheHitRate: cacheHitRate, perModel: perModel, daily: merged,
                           advice: advice, topSessions: topSessions)
    }
}
