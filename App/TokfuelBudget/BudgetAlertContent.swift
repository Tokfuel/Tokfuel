import Foundation
import TokfuelCore
import TokfuelSettings

// BudgetMonitor.Kind / Message と同じモジュール。BudgetLevel は Core。

/// アラートウィンドウに出す 1 件の中身。`BudgetMonitor` の判断結果をそのまま運ぶ。
public struct BudgetAlertContent: Equatable, Sendable {
    public var kind: BudgetMonitor.Kind
    public var level: BudgetLevel
    public var spend: Double
    public var limit: Double
    public var message: BudgetMonitor.Message

    public init(kind: BudgetMonitor.Kind, level: BudgetLevel, spend: Double, limit: Double,
                message: BudgetMonitor.Message) {
        self.kind = kind
        self.level = level
        self.spend = spend
        self.limit = limit
        self.message = message
    }

    public var periodLabel: String { kind.periodLabel }
    public var isOver: Bool { level == .over }
    public var percent: Int { BudgetMonitor.percent(spend: spend, limit: limit) }
    public var ratio: Double { limit > 0 ? min(spend / limit, 1) : 0 }
}
