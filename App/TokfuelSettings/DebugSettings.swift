#if DEBUG
import Foundation
import Combine
import TokfuelCore

/// このファイルは DEBUG ビルドにしか存在しない（`#if DEBUG` でまるごと囲っている）。
/// 上書き値は永続化しない。偽の数値を抱えたまま常駐し続けないよう、再起動で必ず素に戻る。
@MainActor
public final class DebugSettings: ObservableObject {
    public static let shared = DebugSettings()

    @Published public var isActive = false
    @Published public var todayCost: Double = 3
    @Published public var monthCost: Double = 120
    @Published public var averageCost: Double = 4

    @Published public var simulatesMissingReport = false
    /// 実際も起動直後は月側のほうが遅れて届くので、片方だけ欠けた状態は普通に起こる。
    @Published public var simulatesMissingMonth = false

    public var today: Double? { isActive && !simulatesMissingReport ? todayCost : nil }
    public var month: Double? { isActive && !simulatesMissingMonth ? monthCost : nil }
    /// 日次平均は月側と同じ 32 日集計から出るので、未取得の再現も月側に合わせる。
    public var average: Double? { isActive && !simulatesMissingMonth ? averageCost : nil }

    private init() {}
}
#endif
