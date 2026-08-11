import Foundation

/// 1 日分の Claude Code 利用回数。コストは retok のレポートを正とする。
public struct DailyUsage: Identifiable, Codable, Sendable, Equatable {
    public let date: String
    public var id: String { date }
    public var prompts: Int = 0
    public var sessions: Int = 0

    public init(date: String, prompts: Int = 0, sessions: Int = 0) {
        self.date = date
        self.prompts = prompts
        self.sessions = sessions
    }
}
