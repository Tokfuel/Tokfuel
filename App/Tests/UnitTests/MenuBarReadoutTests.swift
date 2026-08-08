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

/// どちらの構成を入れたか分からなくなるのを防ぐ目印。
/// リリースビルドでは何も付かないことも合わせて押さえる。
struct MenuBarDebugMarkerTests {
    @Test func 構成に応じて目印を付ける() {
        #if DEBUG
        #expect(MenuBarReadout.debugMarker == "DEBUG")
        #expect(MenuBarReadout.buildLabel("今日: $1") == "[DEBUG] 今日: $1")
        #expect(MenuBarReadout.windowTitle("Tokfuel 設定") == "Tokfuel 設定（DEBUG）")
        #else
        #expect(MenuBarReadout.debugMarker.isEmpty)
        #expect(MenuBarReadout.buildLabel("今日: $1") == "今日: $1")
        #expect(MenuBarReadout.windowTitle("Tokfuel 設定") == "Tokfuel 設定")
        #endif
    }
}

/// UserDefaults に永続化される値なので、rawValue の変更は既存ユーザーの設定を壊す。
struct MenuBarSettingRawValueTests {
    @Test func 指標のrawValueは変えない() {
        #expect(MenuBarMetric(rawValue: "today") == .today)
        #expect(MenuBarMetric(rawValue: "month") == .month)
        #expect(MenuBarMetric(rawValue: "both") == .both)
        #expect(MenuBarMetric(rawValue: "prompts") == .prompts)
    }

    @Test func 表現のrawValueは変えない() {
        #expect(MenuBarRepresentation(rawValue: "amount") == .amount)
        #expect(MenuBarRepresentation(rawValue: "percent") == .percent)
        #expect(MenuBarRepresentation(rawValue: "ring") == .ring)
        #expect(MenuBarRepresentation(rawValue: "ringAndValue") == .ringAndValue)
        #expect(MenuBarRepresentation(rawValue: "iconOnly") == .iconOnly)
    }

    @Test func 基準のrawValueは変えない() {
        #expect(MenuBarPercentBasis(rawValue: "budgetLimit") == .budgetLimit)
        #expect(MenuBarPercentBasis(rawValue: "dailyAverage30") == .dailyAverage30)
    }

    @Test func 月間集計を要求する指標だけがそう名乗る() {
        #expect(MenuBarMetric.month.showsMonthlyCost)
        #expect(MenuBarMetric.both.showsMonthlyCost)
        #expect(!MenuBarMetric.today.showsMonthlyCost)
        #expect(!MenuBarMetric.prompts.showsMonthlyCost)
    }
}

/// 1 つの enum だった頃の設定を捨てずに引き継ぐ。ここが崩れると既存ユーザーの
/// メニューバーが黙って既定表示に戻る。
struct MenuBarMigrationTests {
    @Test func 旧設定は指標と表現に読み替えられる() {
        let cost = MenuBarReadout.migrated(legacy: "cost")
        #expect(cost?.metric == .today)
        #expect(cost?.representation == .amount)

        let monthly = MenuBarReadout.migrated(legacy: "monthlyCost")
        #expect(monthly?.metric == .month)
        #expect(monthly?.representation == .amount)

        let both = MenuBarReadout.migrated(legacy: "bothCosts")
        #expect(both?.metric == .both)
        #expect(both?.representation == .amount)

        let prompts = MenuBarReadout.migrated(legacy: "prompts")
        #expect(prompts?.metric == .prompts)
        #expect(prompts?.representation == .amount)
    }

    @Test func アイコンのみは表現だけを決めて指標は既定にする() {
        let iconOnly = MenuBarReadout.migrated(legacy: "iconOnly")
        #expect(iconOnly?.representation == .iconOnly)
        #expect(iconOnly?.metric == .today)
    }

    @Test func 未設定と未知の値は移行しない() {
        #expect(MenuBarReadout.migrated(legacy: nil) == nil)
        #expect(MenuBarReadout.migrated(legacy: "") == nil)
        #expect(MenuBarReadout.migrated(legacy: "ringGauge") == nil)
    }
}

/// パーセントとリングが共有する分母の決め方。
struct MenuBarGaugeTests {
    @Test func 予算上限基準は上限をそのまま分母にする() {
        let gauge = MenuBarReadout.gauge(basis: .budgetLimit, todaySpend: 3, monthSpend: 90,
                                         dailyLimit: 5, monthlyLimit: 200,
                                         dailyAverage: 4, activeDays: 10)
        #expect(gauge.todayBasis == 5)
        #expect(gauge.monthBasis == 200)
        #expect(gauge.todaySpend == 3)
        #expect(gauge.monthSpend == 90)
    }

    @Test func 日次平均基準の月側は平均ペースの累計になる() {
        let gauge = MenuBarReadout.gauge(basis: .dailyAverage30, todaySpend: 3, monthSpend: 90,
                                         dailyLimit: 5, monthlyLimit: 200,
                                         dailyAverage: 4, activeDays: 10)
        #expect(gauge.todayBasis == 4)
        #expect(gauge.monthBasis == 40)   // 稼働 1 日あたり 4 × 稼働 10 日
    }

    @Test func 平常運転の月は100パーセントになる() {
        // 平均は「実績のある日」で割るので、掛ける相手も暦日数ではなく稼働日数。
        // 平日だけ使う人（30 日中 22 日）が平常運転なら 100% と読めること。
        let gauge = MenuBarReadout.gauge(basis: .dailyAverage30, todaySpend: 10, monthSpend: 220,
                                         dailyLimit: 0, monthlyLimit: 0,
                                         dailyAverage: 10, activeDays: 22)
        #expect(gauge.monthBasis == 220)
        #expect(MenuBarReadout.percentText(spend: gauge.monthSpend, basis: gauge.monthBasis,
                                          showsRemaining: false) == "100%")
    }

    @Test func 稼働日数がゼロでも月側の分母は潰れない() {
        let gauge = MenuBarReadout.gauge(basis: .dailyAverage30, todaySpend: 0, monthSpend: 0,
                                         dailyLimit: 0, monthlyLimit: 0,
                                         dailyAverage: 4, activeDays: 0)
        #expect(gauge.monthBasis == 4)
    }

    @Test func 平均が未算出なら分母は立たない() {
        let gauge = MenuBarReadout.gauge(basis: .dailyAverage30, todaySpend: 3, monthSpend: 90,
                                         dailyLimit: 5, monthlyLimit: 200,
                                         dailyAverage: 0, activeDays: 10)
        #expect(gauge.todayBasis == 0)
        #expect(gauge.monthBasis == 0)
    }
}

/// 消費 / 基準 → 塗り分率・パーセント文字列。
struct MenuBarRatioTests {
    @Test func 基準がなければ割合を出さない() {
        #expect(MenuBarReadout.fraction(spend: 1, basis: 0) == nil)
        #expect(MenuBarReadout.fraction(spend: 1, basis: -5) == nil)
        #expect(MenuBarReadout.ringFill(spend: 1, basis: 0, showsRemaining: false) == nil)
        #expect(MenuBarReadout.percentText(spend: 1, basis: 0, showsRemaining: false) == nil)
    }

    @Test func リングは100パーセントでクランプする() {
        #expect(MenuBarReadout.ringFill(spend: 50, basis: 100, showsRemaining: false) == 0.5)
        #expect(MenuBarReadout.ringFill(spend: 142, basis: 100, showsRemaining: false) == 1)
        #expect(MenuBarReadout.ringFill(spend: -5, basis: 100, showsRemaining: false) == 0)
    }

    @Test func 残りモードのリングは残り分を塗る() {
        #expect(MenuBarReadout.ringFill(spend: 25, basis: 100, showsRemaining: true) == 0.75)
        // 超過しても負にはならず、空のリングで止まる。
        #expect(MenuBarReadout.ringFill(spend: 142, basis: 100, showsRemaining: true) == 0)
    }

    @Test func パーセントは100を超えてもクランプしない() {
        #expect(MenuBarReadout.percentText(spend: 142, basis: 100, showsRemaining: false) == "142%")
        #expect(MenuBarReadout.percentText(spend: 142, basis: 100, showsRemaining: true) == "-42%")
    }

    @Test func パーセントは四捨五入した整数で出す() {
        #expect(MenuBarReadout.percentText(spend: 0, basis: 100, showsRemaining: false) == "0%")
        #expect(MenuBarReadout.percentText(spend: 78.5, basis: 100, showsRemaining: false) == "79%")
        #expect(MenuBarReadout.percentText(spend: 25, basis: 100, showsRemaining: true) == "75%")
    }

    @Test func 極端に小さい基準でも桁が溢れない() {
        // Int 変換のクラッシュ回避。100% でのクランプではない。
        #expect(MenuBarReadout.percentText(spend: 1, basis: 1e-300,
                                          showsRemaining: false) == "999999%")
    }
}

/// 設定 UI で選べるか。判定に使うのは設定値だけで、非同期に届く集計値は見ない。
/// 集計値で塞ぐと「選ばないと集計が走らない → 永久に選べない」の行き止まりになる。
struct MenuBarSelectabilityTests {
    private func selectable(_ metric: MenuBarMetric, _ representation: MenuBarRepresentation,
                            _ basis: MenuBarPercentBasis,
                            daily: Double = 0, monthly: Double = 0) -> Bool {
        MenuBarReadout.isSelectable(metric: metric, representation: representation, basis: basis,
                                    dailyLimit: daily, monthlyLimit: monthly)
    }

    @Test func 分母が要らない表現は常に選べる() {
        #expect(selectable(.today, .amount, .budgetLimit))
        #expect(selectable(.prompts, .iconOnly, .budgetLimit))
    }

    @Test func プロンプト数では割合表現を選べない() {
        #expect(!selectable(.prompts, .percent, .budgetLimit, daily: 10, monthly: 100))
        #expect(!selectable(.prompts, .ring, .dailyAverage30))
        #expect(!selectable(.prompts, .ringAndValue, .dailyAverage30))
    }

    @Test func 予算上限基準は対応する上限を要求する() {
        #expect(!selectable(.today, .ring, .budgetLimit))
        #expect(selectable(.today, .ring, .budgetLimit, daily: 10))
        #expect(!selectable(.month, .ring, .budgetLimit, daily: 10))
        #expect(selectable(.month, .ring, .budgetLimit, monthly: 100))
        // 今日と今月は両方の上限を要求する（片側だけ欠けたリングを出さない）。
        #expect(!selectable(.both, .ring, .budgetLimit, daily: 10))
        #expect(selectable(.both, .ring, .budgetLimit, daily: 10, monthly: 100))
    }

    @Test func 日次平均基準は予算なしでも選べる() {
        // 選んだ時点で 32 日集計が走って分母が入るので、値の到着を待たずに選ばせる。
        #expect(selectable(.today, .ring, .dailyAverage30))
        #expect(selectable(.both, .percent, .dailyAverage30))
    }

    @Test func 選べない理由を区別して返す() {
        #expect(MenuBarReadout.ratioUnavailability(metric: .prompts, basis: .dailyAverage30,
                                                   dailyLimit: 10, monthlyLimit: 100) == .noRatio)
        #expect(MenuBarReadout.ratioUnavailability(metric: .today, basis: .budgetLimit,
                                                   dailyLimit: 0, monthlyLimit: 100) == .noLimit)
        #expect(MenuBarReadout.ratioUnavailability(metric: .today, basis: .dailyAverage30,
                                                   dailyLimit: 0, monthlyLimit: 0) == nil)
    }
}

/// 実際に描けるか（分母が入っているか）。描けなければ金額表示に落とす。
struct MenuBarRenderabilityTests {
    private let full = MenuBarGauge(todaySpend: 5, todayBasis: 10,
                                   monthSpend: 25, monthBasis: 100)

    @Test func 今日と今月は両方の分母を要求する() {
        let onlyToday = MenuBarGauge(todaySpend: 5, todayBasis: 10)
        #expect(MenuBarReadout.canRender(metric: .today, representation: .ring, gauge: onlyToday))
        #expect(!MenuBarReadout.canRender(metric: .month, representation: .ring, gauge: onlyToday))
        #expect(!MenuBarReadout.canRender(metric: .both, representation: .ring, gauge: onlyToday))
        #expect(MenuBarReadout.canRender(metric: .both, representation: .ring, gauge: full))
    }

    @Test func 描けない表現は金額に落ちアイコンのみは残る() {
        let none = MenuBarGauge()
        #expect(MenuBarReadout.effectiveRepresentation(metric: .today, representation: .ring,
                                                       gauge: none) == .amount)
        #expect(MenuBarReadout.effectiveRepresentation(metric: .prompts, representation: .percent,
                                                       gauge: none) == .amount)
        #expect(MenuBarReadout.effectiveRepresentation(metric: .today, representation: .iconOnly,
                                                       gauge: none) == .iconOnly)
        #expect(MenuBarReadout.effectiveRepresentation(metric: .today, representation: .ring,
                                                       gauge: MenuBarGauge(todayBasis: 10))
                == .ring)
    }
}

/// メニューバーに出す内容の組み立て。金額の書式は表示通貨に依存するため、
/// ここでは通貨に依らない性質だけを見る（書式そのものは MoneyFormattingTests が持つ）。
struct MenuBarContentTests {
    @Test func リング表現は数字を持たない() {
        let input = MenuBarInput(metric: .today, representation: .ring,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
        let content = MenuBarReadout.content(for: input)
        #expect(content.title.isEmpty)
        #expect(content.gauges.map(\.fill) == [0.5])
    }

    @Test func 今日と今月のリングは内側が日次で外側が月次() {
        let input = MenuBarInput(metric: .both, representation: .ring,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10,
                                                     monthSpend: 25, monthBasis: 100))
        // 先頭 = 内側 = 今日、次 = 外側 = 今月。
        #expect(MenuBarReadout.content(for: input).gauges.map(\.fill) == [0.5, 0.25])
    }

    @Test func パーセント表現は両側を並べる() {
        let input = MenuBarInput(metric: .both, representation: .percent,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10,
                                                     monthSpend: 25, monthBasis: 100))
        let content = MenuBarReadout.content(for: input)
        #expect(content.title == "50% · 月 25%")
        #expect(content.gauges.isEmpty)
    }

    @Test func リングと数値はリングと同じ割合を数字でも出す() {
        // リングは割合のインジケーターなので、添える数字も割合。
        // リングが形で示す値に、桁で読める精度を足す関係にする。
        let input = MenuBarInput(metric: .today, representation: .ringAndValue,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
        let content = MenuBarReadout.content(for: input)
        #expect(content.gauges.map(\.fill) == [0.5])
        #expect(content.title == "50%")
    }

    @Test func リングと数値は超過をクランプせず桁で出す() {
        // リングは満タンで止まるが、どれだけ超えたかは数字だけが伝えられる。
        let input = MenuBarInput(metric: .today, representation: .ringAndValue,
                                 gauge: MenuBarGauge(todaySpend: 14.2, todayBasis: 10))
        let content = MenuBarReadout.content(for: input)
        #expect(content.gauges.map(\.fill) == [1])
        #expect(content.title == "142%")
    }

    @Test func 分母がなければリングは消えて金額だけ残る() {
        let input = MenuBarInput(metric: .today, representation: .ring)
        let content = MenuBarReadout.content(for: input)
        #expect(content.gauges.isEmpty)
        #expect(!content.title.isEmpty)
    }

    @Test func アイコンのみは数字もリングも持たない() {
        let content = MenuBarReadout.content(for: MenuBarInput(representation: .iconOnly))
        #expect(content.title.isEmpty)
        #expect(content.gauges.isEmpty)
        #expect(content.toolTip == MenuBarReadout.buildLabel("Tokfuel"))
    }

    @Test func プロンプト数は件数をそのまま出す() {
        let content = MenuBarReadout.content(
            for: MenuBarInput(metric: .prompts, representation: .ring, prompts: 42))
        #expect(content.title == "42")
        #expect(content.toolTip == MenuBarReadout.buildLabel("今日のプロンプト数: 42"))
        #expect(content.gauges.isEmpty)
    }

    @Test func ツールチップは割合も併記する() {
        let input = MenuBarInput(metric: .today, representation: .ring,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
        #expect(MenuBarReadout.content(for: input).toolTip.contains("（50%）"))
    }

    @Test func ゲージは基準にかかわらず予算レベルの色を受け取る() {
        // ゲージは給油機アイコンと入れ替わるので、ここで色を落とすと予算超過の赤が
        // どこにも出なくなる。分母の取り方（基準）とは無関係に渡す。
        for basis in MenuBarPercentBasis.allCases {
            let input = MenuBarInput(metric: .today, representation: .ring, basis: basis,
                                     gauge: MenuBarGauge(todaySpend: 9, todayBasis: 10),
                                     todayLevel: .over)
            #expect(MenuBarReadout.content(for: input).gauges.first?.level == .over)
        }
    }

    /// 今日だけしきい値を越えたら、今日のゲージだけ色が変わる。
    @Test func ゲージは側ごとに色を持つ() {
        let input = MenuBarInput(metric: .both, representation: .ring,
                                 gauge: MenuBarGauge(todaySpend: 9, todayBasis: 10,
                                                     monthSpend: 10, monthBasis: 100),
                                 todayLevel: .warning, monthLevel: .ok)
        #expect(MenuBarReadout.content(for: input).gauges.map(\.level) == [.warning, .ok])
    }

    @Test func アイコンの色は悪い方のレベルを使う() {
        // 給油機アイコン単体はメニューバーに 1 つしか出ないので、危ない側を代表させる。
        let input = MenuBarInput(metric: .both, representation: .amount,
                                 todayLevel: .ok, monthLevel: .over)
        #expect(MenuBarReadout.content(for: input).iconLevel == .over)
    }

    @Test func リングと一緒にアイコンも出せる() {
        // リングは給油機アイコンと入れ替わるので、並べたい人のために選べるようにする。
        var input = MenuBarInput(metric: .today, representation: .ring, showsIcon: true,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
        #expect(MenuBarReadout.content(for: input).showsIcon)
        input.showsIcon = false
        #expect(!MenuBarReadout.content(for: input).showsIcon)
    }

    @Test func タンクはアイコン自身がゲージなので併記できない() {
        // アイコンを別に並べると給油機が 2 つ出てしまう。
        let input = MenuBarInput(metric: .today, representation: .ring, shape: .tank,
                                 showsIcon: false,
                                 gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
        let content = MenuBarReadout.content(for: input)
        #expect(content.showsIcon)
        #expect(content.shape == .tank)
        #expect(content.gauges.count == 1)
    }

    @Test func 文字だけの表現ではアイコンを消せない() {
        // 数字だけが浮いていると、何のアプリの値なのか分からなくなる。
        for representation in [MenuBarRepresentation.amount, .percent, .iconOnly] {
            let input = MenuBarInput(metric: .today, representation: representation,
                                     showsIcon: false,
                                     gauge: MenuBarGauge(todaySpend: 5, todayBasis: 10))
            #expect(MenuBarReadout.content(for: input).showsIcon)
        }
    }

    @Test func ゲージを描かない表現はゲージを持たない() {
        let input = MenuBarInput(metric: .today, representation: .amount,
                                 gauge: MenuBarGauge(todaySpend: 9, todayBasis: 10),
                                 todayLevel: .over)
        #expect(MenuBarReadout.content(for: input).gauges.isEmpty)
    }

    @Test func 残り表示は予算上限基準のときだけ割合を反転する() {
        // 「いつもの 1 日に対する残り」という概念は無いので、平均基準では消費側の割合を出す。
        // 金額（残 上限 − 消費）と割合が食い違わないようにする。
        let average = MenuBarInput(metric: .today, representation: .percent,
                                   basis: .dailyAverage30, showsRemaining: true,
                                   gauge: MenuBarGauge(todaySpend: 9, todayBasis: 4),
                                   dailyLimit: 10)
        #expect(MenuBarReadout.content(for: average).title == "225%")

        let limit = MenuBarInput(metric: .today, representation: .percent,
                                 basis: .budgetLimit, showsRemaining: true,
                                 gauge: MenuBarGauge(todaySpend: 9, todayBasis: 10),
                                 dailyLimit: 10)
        #expect(MenuBarReadout.content(for: limit).title == "10%")
    }

    @Test func 有限でない消費額は割合にしない() {
        #expect(MenuBarReadout.fraction(spend: .nan, basis: 10) == nil)
        #expect(MenuBarReadout.percentText(spend: .infinity, basis: 10,
                                          showsRemaining: false) == nil)
        #expect(MenuBarReadout.ringFill(spend: .nan, basis: 10, showsRemaining: false) == nil)
    }

    @Test func 分母がなければツールチップは金額だけ() {
        let input = MenuBarInput(metric: .today, representation: .amount)
        let toolTip = MenuBarReadout.content(for: input).toolTip
        #expect(toolTip.contains("今日の推定コスト: "))
        #expect(!toolTip.contains("%"))
    }

    @Test func 残額モードのツールチップは残り予算と名乗る() {
        let input = MenuBarInput(metric: .today, representation: .amount, showsRemaining: true,
                                 dailyLimit: 10)
        #expect(MenuBarReadout.content(for: input).toolTip.contains("今日の残り予算: "))
    }
}
