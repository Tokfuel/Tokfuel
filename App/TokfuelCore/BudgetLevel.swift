import Foundation

/// 予算に対する現在の消費レベル。
public enum BudgetLevel: Int, Comparable, Sendable {
    case ok = 0
    case warning = 1
    case over = 2

    public static func < (lhs: BudgetLevel, rhs: BudgetLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}
