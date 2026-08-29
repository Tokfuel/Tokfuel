import Foundation

/// 使用額が動いている間だけ更新間隔を上げる「追従モード」の状態機械（TF-0080）。
/// タイマーもストアも触らない。時刻を引数で受け取るのは、テストから固定値を渡せるようにするため
struct RefreshScheduler {
    static let baseInterval: TimeInterval = 600
    static let followInterval: TimeInterval = 60
    static let followDuration: TimeInterval = 300
    /// 発火とみなす増加額の下限 (USD)。浮動小数の誤差だけで追従モードに入らないための閾値。
    static let costEpsilon: Double = 0.000001

    struct Decision: Equatable {
        let interval: TimeInterval
        let isFollowing: Bool
        let followRemaining: TimeInterval
        let intervalChanged: Bool
    }

    /// （一時的に取得できなかっただけのソースが、復帰時に増加として誤発火しないようにする）。
    private var lastCosts: [String: Double] = [:]
    /// 1 回でも観測したか。初回は比較相手が無いので、起動直後の「0 → 実額」で発火させない。
    private var hasBaseline = false
    private(set) var followUntil: Date?
    private(set) var appliedInterval: TimeInterval = RefreshScheduler.baseInterval

    func isFollowing(at now: Date) -> Bool {
        guard let followUntil else { return false }
        return now < followUntil
    }

    mutating func observe(costs: [String: Double], now: Date, enabled: Bool = true) -> Decision {
        // 設定がオフでも観測値は記録する。オンに戻した瞬間、オフの間の増加分で発火しない。
        let moved = enabled && increased(to: costs)
        for (id, cost) in costs { lastCosts[id] = cost }
        hasBaseline = true
        if moved { followUntil = now.addingTimeInterval(Self.followDuration) }
        return resolve(now: now, enabled: enabled)
    }

    @discardableResult
    mutating func resolve(now: Date, enabled: Bool = true) -> Decision {
        if !enabled { followUntil = nil }
        let following = isFollowing(at: now)
        if !following { followUntil = nil }
        let interval = following ? Self.followInterval : Self.baseInterval
        let changed = interval != appliedInterval
        appliedInterval = interval
        let remaining = following ? (followUntil?.timeIntervalSince(now) ?? 0) : 0
        return Decision(interval: interval, isFollowing: following,
                        followRemaining: remaining, intervalChanged: changed)
    }

    /// いずれかのソースの金額が閾値を超えて増えたか。減少（過去日の再計算）では発火しない。
    private func increased(to costs: [String: Double]) -> Bool {
        guard hasBaseline else { return false }
        return costs.contains { id, cost in cost - (lastCosts[id] ?? 0) > Self.costEpsilon }
    }
}
