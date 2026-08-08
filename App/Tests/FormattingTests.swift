import Foundation
import Testing
@testable import Tokfuel

/// 表示通貨の設定（UserDefaults）を共有するため直列実行にする。
@Suite(.serialized)
struct MoneyFormattingTests {
    /// テスト中だけ表示通貨とレートを設定し、終わったら消す。
    private func withJPY(rate: Double?, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        defaults.set(DisplayCurrency.jpy.rawValue, forKey: Money.currencyKey)
        if let rate { defaults.set(rate, forKey: Money.rateKey) }
        defer {
            defaults.removeObject(forKey: Money.currencyKey)
            defaults.removeObject(forKey: Money.rateKey)
        }
        body()
    }

    @Test func 百ドル未満はセント2桁() {
        #expect(PopoverView.money(0) == "$0.00")
        #expect(PopoverView.money(0.05) == "$0.05")
        #expect(PopoverView.money(99.99) == "$99.99")
    }

    @Test func 百ドル以上は整数表示() {
        #expect(PopoverView.money(100) == "$100")
        #expect(PopoverView.money(1234.56) == "$1235")
    }

    @Test func 日本円はレートで換算し整数円で桁区切り() {
        withJPY(rate: 150) {
            #expect(PopoverView.money(2) == "¥300")
            #expect(PopoverView.money(10) == "¥1,500")
        }
    }

    @Test func レート未取得の日本円はドルにフォールバック() {
        withJPY(rate: nil) {
            #expect(PopoverView.money(2) == "$2.00")
        }
    }

    @Test func チャート軸の円は桁区切りなしで万以上は畳む() {
        #expect(Money.formatAxis(0, currency: .jpy, rate: 150) == "¥0")
        #expect(Money.formatAxis(1500, currency: .jpy, rate: 150) == "¥1500")
        #expect(Money.formatAxis(10_000, currency: .jpy, rate: 150) == "¥1万")
        #expect(Money.formatAxis(25_000, currency: .jpy, rate: 150) == "¥2.5万")
        #expect(Money.formatAxis(12, currency: .usd, rate: 0) == "$12")
    }

    // メニューバーのタイトルは金額の書式に乗るため、表示通貨を握っているこのスイート内に置く
    // （別スイートに置くと、上のテストが円に切り替えている間と並走して落ちる）。
    // 通貨に依らない組み立ての性質は MenuBarContentTests が受け持つ。

    @Test func 今日と今月の金額は中黒と月で並ぶ() {
        let input = MenuBarInput(metric: .both, representation: .amount,
                                 gauge: MenuBarGauge(todaySpend: 12.34, monthSpend: 210))
        #expect(MenuBarReadout.content(for: input).title == "$12.34 · 月 $210")
    }

    @Test func 残額モードは上限との差を残として出す() {
        let input = MenuBarInput(metric: .today, representation: .amount, showsRemaining: true,
                                 gauge: MenuBarGauge(todaySpend: 4), dailyLimit: 10)
        #expect(MenuBarReadout.content(for: input).title == "残 $6.00")
    }

    @Test func 上限が未設定なら残額モードでも消費額のまま() {
        let input = MenuBarInput(metric: .today, representation: .amount, showsRemaining: true,
                                 gauge: MenuBarGauge(todaySpend: 4))
        #expect(MenuBarReadout.content(for: input).title == "$4.00")
    }
}
