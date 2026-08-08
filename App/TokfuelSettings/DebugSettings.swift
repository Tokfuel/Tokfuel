#if DEBUG
import Foundation
import Combine
import TokfuelCore

/// 開発者向けの値上書き。実データが揃うのを待たずに、メニューバー表示・アイコン色・
/// 予算アラートを任意の金額で確かめるために使う。
///
/// このファイルは DEBUG ビルドにしか存在しない（`#if DEBUG` でまるごと囲っている）。
/// 配布するリリースビルドにはデバッグ UI もこの型も含まれない。確認したいときは
/// `bash Scripts/build.sh --debug` で debug 構成の Tokfuel.app を入れる。
///
/// 上書き値は永続化しない。偽の数値を抱えたまま常駐し続けないよう、再起動で必ず素に戻る。
@MainActor
public final class DebugSettings: ObservableObject {
    public static let shared = DebugSettings()

    /// 上書きの一括スイッチ。OFF の間は実データがそのまま出る。
    @Published public var isActive = false
    @Published public var todayCost: Double = 3
    @Published public var monthCost: Double = 120
    /// メニューバーの日次平均基準（リング・パーセントの分母）。予算に依らない
    /// テンプレート配色のリングを実データ待ちなしで確かめるために上書きできる。
    @Published public var averageCost: Double = 4

    /// 今日側（ポップオーバーと共用の retok レポート）の未取得を再現する。
    /// 今日のコストが 0 になり、推移・内訳・上位セッションは読み込み中表示に落ちる。
    @Published public var simulatesMissingReport = false
    /// 月側（予算用の 32 日集計。今日側とは別実行）の未取得を再現する。
    /// 実際も起動直後は月側のほうが遅れて届くので、片方だけ欠けた状態は普通に起こる。
    @Published public var simulatesMissingMonth = false

    /// 上書き中の金額。`nil` なら実データを使う。未取得の再現が勝つ。
    public var today: Double? { isActive && !simulatesMissingReport ? todayCost : nil }
    public var month: Double? { isActive && !simulatesMissingMonth ? monthCost : nil }
    /// 日次平均は月側と同じ 32 日集計から出るので、未取得の再現も月側に合わせる。
    public var average: Double? { isActive && !simulatesMissingMonth ? averageCost : nil }

    private init() {}
}
#endif
