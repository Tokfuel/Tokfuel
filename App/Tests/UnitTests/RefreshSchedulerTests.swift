import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
@testable import Tokfuel

/// 追従モード（TF-0080）の状態遷移。発火の閾値・リセット・復帰の境界を突く。
/// 時刻は引数で渡すので、待たずに 5 分後を作れる。
struct RefreshSchedulerTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let base = RefreshScheduler.baseInterval
    private let follow = RefreshScheduler.followInterval
    private let duration = RefreshScheduler.followDuration

    /// 起動直後の「未観測 → 実額」は動きとみなさない（毎回の起動で追従に入ってしまう）。
    @Test func 初回の観測では追従しない() {
        var scheduler = RefreshScheduler()
        let decision = scheduler.observe(costs: ["claude": 12.34], now: t0)
        #expect(decision.isFollowing == false)
        #expect(decision.interval == base)
        #expect(decision.intervalChanged == false)
        #expect(decision.followRemaining == 0)
    }

    @Test func 金額が増えたら1分間隔に上げる() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        let decision = scheduler.observe(costs: ["claude": 1.01], now: t0.addingTimeInterval(600))
        #expect(decision.isFollowing)
        #expect(decision.interval == follow)
        #expect(decision.intervalChanged)
        #expect(decision.followRemaining == duration)
    }

    /// 浮動小数の誤差だけでは発火しない。閾値ちょうども発火させない（超えたときだけ）。
    @Test func 閾値以下の増分では発火しない() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        let epsilon = RefreshScheduler.costEpsilon
        let same = scheduler.observe(costs: ["claude": 1.0 + epsilon / 2],
                                     now: t0.addingTimeInterval(1))
        #expect(same.isFollowing == false)
        let exact = scheduler.observe(costs: ["claude": 1.0 + epsilon],
                                      now: t0.addingTimeInterval(2))
        #expect(exact.isFollowing == false)
        let over = scheduler.observe(costs: ["claude": 1.0 + epsilon * 3],
                                     now: t0.addingTimeInterval(3))
        #expect(over.isFollowing)
    }

    /// 過去日の再計算でコストが下がることがある。減少では追従に入らない。
    @Test func 減少では発火しない() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 5.0], now: t0)
        let decision = scheduler.observe(costs: ["claude": 4.0], now: t0.addingTimeInterval(60))
        #expect(decision.isFollowing == false)
        #expect(decision.interval == base)
    }

    /// ソースは独立に見る。Claude が止まっていても Cursor が動けば追従する。
    @Test func 別ソースの増加でも発火する() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 5.0, "cursor": 1.0], now: t0)
        let decision = scheduler.observe(costs: ["claude": 5.0, "cursor": 1.5],
                                         now: t0.addingTimeInterval(60))
        #expect(decision.isFollowing)
    }

    /// 後から見つかったソース（Cursor の初回スナップショット）は 0 からの増加として扱う。
    @Test func 新しいソースの出現でも発火する() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 5.0], now: t0)
        let decision = scheduler.observe(costs: ["claude": 5.0, "codex": 0.4],
                                         now: t0.addingTimeInterval(60))
        #expect(decision.isFollowing)
    }

    /// 一時的に取得できず消えたソースが、次に同じ値で戻ってきても再発火しない。
    @Test func 消えたソースの復帰では発火しない() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 5.0, "cursor": 2.0], now: t0)
        _ = scheduler.observe(costs: ["claude": 5.0], now: t0.addingTimeInterval(60))
        let decision = scheduler.observe(costs: ["claude": 5.0, "cursor": 2.0],
                                         now: t0.addingTimeInterval(120))
        #expect(decision.isFollowing == false)
    }

    /// 5 分ちょうどで切れる。直前までは追従、境界では基準間隔へ戻る。
    @Test func 無風のまま5分で基準間隔へ戻る() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        _ = scheduler.observe(costs: ["claude": 2.0], now: t0)

        let justBefore = scheduler.observe(costs: ["claude": 2.0],
                                           now: t0.addingTimeInterval(duration - 1))
        #expect(justBefore.isFollowing)
        #expect(justBefore.interval == follow)
        #expect(justBefore.intervalChanged == false)
        #expect(justBefore.followRemaining == 1)

        let expired = scheduler.observe(costs: ["claude": 2.0],
                                        now: t0.addingTimeInterval(duration))
        #expect(expired.isFollowing == false)
        #expect(expired.interval == base)
        #expect(expired.intervalChanged)
        #expect(scheduler.followUntil == nil)
    }

    /// 追従中に動くたび、残り時間は 5 分へ戻る（最初の発火から 5 分では切れない）。
    @Test func 追従中に動いたら残り時間をリセットする() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        _ = scheduler.observe(costs: ["claude": 2.0], now: t0)

        let again = scheduler.observe(costs: ["claude": 3.0],
                                      now: t0.addingTimeInterval(duration - 60))
        #expect(again.followRemaining == duration)

        // 最初の発火から 5 分を過ぎても、リセット後の 5 分はまだ残っている。
        let later = scheduler.resolve(now: t0.addingTimeInterval(duration + 60))
        #expect(later.isFollowing)
        #expect(later.interval == follow)

        let end = scheduler.resolve(now: t0.addingTimeInterval(duration * 2 - 60))
        #expect(end.isFollowing == false)
        #expect(end.interval == base)
    }

    /// タイマー発火時など、金額を観測しない再判定でも期限切れを拾う。
    @Test func 観測なしの再判定でも期限切れで戻る() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        _ = scheduler.observe(costs: ["claude": 2.0], now: t0)
        #expect(scheduler.resolve(now: t0.addingTimeInterval(60)).isFollowing)
        #expect(scheduler.resolve(now: t0.addingTimeInterval(duration)).isFollowing == false)
    }

    /// 設定オフなら常に 10 分。金額が動いても追従しない。
    @Test func 設定オフなら常に基準間隔() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0, enabled: false)
        let decision = scheduler.observe(costs: ["claude": 9.0], now: t0.addingTimeInterval(60),
                                         enabled: false)
        #expect(decision.isFollowing == false)
        #expect(decision.interval == base)
        #expect(decision.intervalChanged == false)
    }

    /// 追従中に設定をオフにしたら、その場で基準間隔へ戻る。
    @Test func 追従中に設定をオフにすると戻る() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        #expect(scheduler.observe(costs: ["claude": 2.0], now: t0).isFollowing)
        let off = scheduler.resolve(now: t0.addingTimeInterval(1), enabled: false)
        #expect(off.isFollowing == false)
        #expect(off.interval == base)
        #expect(off.intervalChanged)
    }

    /// オフの間の増分は、オンに戻した瞬間の発火に使わない（戻した途端に追従に入らない）。
    @Test func オフの間の増分では戻した直後に発火しない() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        _ = scheduler.observe(costs: ["claude": 8.0], now: t0.addingTimeInterval(60),
                              enabled: false)
        let back = scheduler.observe(costs: ["claude": 8.0], now: t0.addingTimeInterval(120))
        #expect(back.isFollowing == false)
    }

    /// 間隔が変わらない回は intervalChanged を立てない（タイマーを張り替え続けない）。
    @Test func 同じ間隔が続く間は張り替えを求めない() {
        var scheduler = RefreshScheduler()
        _ = scheduler.observe(costs: ["claude": 1.0], now: t0)
        #expect(scheduler.observe(costs: ["claude": 2.0], now: t0).intervalChanged)
        #expect(scheduler.observe(costs: ["claude": 3.0],
                                  now: t0.addingTimeInterval(60)).intervalChanged == false)
        #expect(scheduler.resolve(now: t0.addingTimeInterval(120)).intervalChanged == false)
    }
}
