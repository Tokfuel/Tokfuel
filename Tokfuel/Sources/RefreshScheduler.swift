import Foundation

/// 使用額が動いている間だけ更新間隔を上げる「追従モード」の状態機械（TF-0080）。
///
/// 基準は 10 分間隔。1 回の集計でいずれかのソース（Claude / Cursor / Codex）の今日の金額が
/// 増えたら 1 分間隔へ上げ、5 分間まったく動かなければ 10 分間隔へ戻す。追従中にさらに動いたら
/// 残り時間を 5 分へリセットする。
///
/// 判定に必要なものは「現在時刻」「ソース別の今日の金額」「設定でこの機能が有効か」だけで、
/// タイマーもストアも触らない。時刻を引数で受け取るのは、テストから固定値を渡せるようにするため
/// （`App.swift` はここが返した間隔でタイマーを張り替えるだけ）。
struct RefreshScheduler {
    /// 平常時の更新間隔（秒）。
    static let baseInterval: TimeInterval = 600
    /// 追従モード中の更新間隔（秒）。
    static let followInterval: TimeInterval = 60
    /// 1 回の発火で追従モードを延ばす長さ（秒）。
    static let followDuration: TimeInterval = 300
    /// 発火とみなす増加額の下限 (USD)。浮動小数の誤差だけで追従モードに入らないための閾値。
    static let costEpsilon: Double = 0.000001

    /// 状態機械の出力。
    struct Decision: Equatable {
        /// 次の更新間隔（秒）。
        let interval: TimeInterval
        /// 追従モード中か。
        let isFollowing: Bool
        /// 追従モードの残り時間（秒）。追従していなければ 0。
        let followRemaining: TimeInterval
        /// 直前に適用していた間隔から変わったか。タイマーの張り替えはこれが true のときだけでよい。
        let intervalChanged: Bool
    }

    /// ソース ID → 直近に観測した今日の金額。ソースは消えても値を残す
    /// （一時的に取得できなかっただけのソースが、復帰時に増加として誤発火しないようにする）。
    private var lastCosts: [String: Double] = [:]
    /// 1 回でも観測したか。初回は比較相手が無いので、起動直後の「0 → 実額」で発火させない。
    private var hasBaseline = false
    /// 追従モードの終了時刻（追従していなければ nil）。
    private(set) var followUntil: Date?
    /// 直前に返した間隔。`intervalChanged` の判定に使う。
    private(set) var appliedInterval: TimeInterval = RefreshScheduler.baseInterval

    /// 指定時刻に追従モード中か。終了時刻ちょうどは「切れた」とみなす。
    func isFollowing(at now: Date) -> Bool {
        guard let followUntil else { return false }
        return now < followUntil
    }

    /// 新しい集計結果を観測する。金額が増えていれば追従モードに入り（または延長し）、
    /// 動きが無ければ経過時間だけで判定する。
    ///
    /// - Parameters:
    ///   - costs: ソース ID → 今日の金額 (USD)。表示モードで合成する前の生の値を渡す。
    ///   - now: 現在時刻。
    ///   - enabled: 設定（`adaptiveRefreshEnabled`）。false なら常に基準間隔。
    mutating func observe(costs: [String: Double], now: Date, enabled: Bool = true) -> Decision {
        // 設定がオフでも観測値は記録する。オンに戻した瞬間、オフの間の増加分で発火しない。
        let moved = enabled && increased(to: costs)
        for (id, cost) in costs { lastCosts[id] = cost }
        hasBaseline = true
        if moved { followUntil = now.addingTimeInterval(Self.followDuration) }
        return resolve(now: now, enabled: enabled)
    }

    /// 金額を観測せず、経過時間と設定だけで再判定する。タイマー発火時やスリープ復帰時など、
    /// 「無風のまま 5 分が過ぎたか」を確かめたいときに使う。
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
    /// 初回観測は比較相手が無いので常に false。
    private func increased(to costs: [String: Double]) -> Bool {
        guard hasBaseline else { return false }
        // 未知のソースは 0 からの増加として扱う（Cursor が後から見つかった場合など）。
        return costs.contains { id, cost in cost - (lastCosts[id] ?? 0) > Self.costEpsilon }
    }
}
