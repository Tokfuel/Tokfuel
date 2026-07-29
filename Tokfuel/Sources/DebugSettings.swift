#if DEBUG
import Foundation
import Combine

/// 開発者向けの値上書き。実データが揃うのを待たずに、メニューバー表示・アイコン色・
/// 予算アラートを任意の金額で確かめるために使う。
///
/// このファイルは DEBUG ビルドにしか存在しない（`#if DEBUG` でまるごと囲っている）。
/// 配布するリリースビルドにはデバッグ UI もこの型も含まれない。確認したいときは
/// `bash scripts/build.sh --debug` で debug 構成の Tokfuel.app を入れる。
///
/// 上書き値は永続化しない。偽の数値を抱えたまま常駐し続けないよう、再起動で必ず素に戻る。
@MainActor
final class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    /// 上書きの一括スイッチ。OFF の間は実データがそのまま出る。
    @Published var isActive = false
    @Published var todayCost: Double = 3
    @Published var monthCost: Double = 120

    /// 今日側（Cost タブと共用の retok レポート）の未取得を再現する。
    /// 今日のコストが 0 になり、推移・内訳・上位セッションは読み込み中表示に落ちる。
    @Published var simulatesMissingReport = false
    /// 月側（予算用の 32 日集計。今日側とは別実行）の未取得を再現する。
    /// 実際も起動直後は月側のほうが遅れて届くので、片方だけ欠けた状態は普通に起こる。
    @Published var simulatesMissingMonth = false

    /// 上書き中の金額。`nil` なら実データを使う。未取得の再現が勝つ。
    var today: Double? { isActive && !simulatesMissingReport ? todayCost : nil }
    var month: Double? { isActive && !simulatesMissingMonth ? monthCost : nil }

    private init() {}
}
#endif
