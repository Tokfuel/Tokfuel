import AppKit
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

/// 画像に乗ったインクの総量（アルファの合計）。トラックが円周を覆うので
/// 「色の付いたピクセル数」では塗りの増減が出ない。濃さで測る。
private func ink(_ image: NSImage) -> Double {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return 0 }
    var total = 0.0
    for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
            total += Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
        }
    }
    return total
}

/// 画像の下半分／上半分に乗ったインク。タンクが下から塗られることを見るのに使う。
private func inkHalves(_ image: NSImage) -> (bottom: Double, top: Double) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return (0, 0) }
    var bottom = 0.0, top = 0.0
    let mid = bitmap.pixelsHigh / 2
    for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
            let a = Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            // NSBitmapImageRep の y は上が 0。
            if y < mid { top += a } else { bottom += a }
        }
    }
    return (bottom, top)
}

private func seg(_ fills: [Double], _ level: BudgetLevel? = nil) -> [MenuBarGaugeSegment] {
    fills.map { MenuBarGaugeSegment(fill: $0, level: level) }
}

private func content(shape: MenuBarGaugeShape = .ring, showsIcon: Bool = true,
                     gauges: [MenuBarGaugeSegment] = [], iconLevel: BudgetLevel? = nil,
                     label: String = "x") -> MenuBarContent {
    MenuBarContent(toolTip: label, shape: shape, gauges: gauges, showsIcon: showsIcon,
                   iconLevel: iconLevel)
}

/// 配色。リングは段階を常に示すので平常時も色を持ち、アイコン単体は平常時を無彩色に保つ。
struct MenuBarPaletteTests {
    @Test func ゲージは段階で青オレンジ赤に変わる() {
        #expect(menuBarRingColor(for: .ok) == .systemBlue)
        #expect(menuBarRingColor(for: .warning) == .systemOrange)
        #expect(menuBarRingColor(for: .over) == .systemRed)
    }

    @Test func アイコン単体は平常時に色を持たない() {
        #expect(menuBarAlertColor(for: .ok) == nil)
        #expect(menuBarAlertColor(for: .warning) == .systemOrange)
        #expect(menuBarAlertColor(for: .over) == .systemRed)
    }
}

/// リングの見た目そのものは実機で確かめるしかないが、「描けているか」はここで押さえる。
struct MenuBarRingTests {
    @Test func 描ける本数は1本と2本だけ() {
        #expect(MenuBarImage.ring([], template: true) == nil)
        #expect(MenuBarImage.ring(seg([0.5, 0.5, 0.5]), template: true) == nil)
        #expect(MenuBarImage.ring(seg([0.5]), template: true) != nil)
        #expect(MenuBarImage.ring(seg([0.5, 0.5]), template: true) != nil)
    }

    @Test func メニューバーのアイコン寸法で描く() {
        #expect(MenuBarImage.ring(seg([0.5]), template: true)?.size
                == NSSize(width: MenuBarImage.side, height: MenuBarImage.side))
    }

    @Test func 塗りが0でもトラックは描く() {
        // 「使っていない」ことが空のリングとして見えるように、下地は常に出す。
        #expect(ink(MenuBarImage.ring(seg([0]), template: true)!) > 0)
    }

    @Test func 塗りが増えるとインクも濃くなる() {
        let empty = ink(MenuBarImage.ring(seg([0]), template: true)!)
        let quarter = ink(MenuBarImage.ring(seg([0.25]), template: true)!)
        let full = ink(MenuBarImage.ring(seg([1]), template: true)!)
        #expect(quarter > empty)
        #expect(full > quarter)
    }

    @Test func 超過分は満タンで止まる() {
        // クランプが効いていないと弧が二周ぶん引かれて濃さが変わる。
        let full = ink(MenuBarImage.ring(seg([1]), template: true)!)
        let over = ink(MenuBarImage.ring(seg([2.5]), template: true)!)
        #expect(abs(over - full) < 0.001)
    }

    @Test func 二重リングは単一より多く描く() {
        let single = ink(MenuBarImage.ring(seg([1]), template: true)!)
        let double = ink(MenuBarImage.ring(seg([1, 1]), template: true)!)
        #expect(double > single)
    }

    /// 色付きのトラックは、リング色を薄めたものではなくグレーで描く。
    /// 半透明の色は暗いメニューバーで背景と混ざってほぼ見えなくなるため
    /// （非テンプレート画像は明暗に追従できない）。
    @Test func 色付きでもトラックの濃さが保たれる() {
        let plain = ink(MenuBarImage.ring(seg([0]), template: true)!)
        let warning = ink(MenuBarImage.ring(seg([0], .warning), template: false)!)
        #expect(warning > plain * 0.8)
    }
}

/// タンク（給油機を下から塗り上げる燃料計）。
struct MenuBarTankTests {
    private func tank(_ fill: Double, _ level: BudgetLevel? = nil,
                      template: Bool = true) -> NSImage {
        MenuBarImage.tank(MenuBarGaugeSegment(fill: fill, level: level), template: template)
    }

    @Test func アイコン寸法で描く() {
        #expect(tank(0.5).size == NSSize(width: MenuBarImage.side, height: MenuBarImage.side))
    }

    @Test func 塗りが増えるとインクも濃くなる() {
        // 空でもグリフの形は薄く出し、塗るほど濃くなる。
        let empty = ink(tank(0))
        let half = ink(tank(0.5))
        let full = ink(tank(1))
        #expect(empty > 0)
        #expect(half > empty)
        #expect(full > half)
    }

    @Test func 下から塗り上がる() {
        // 半分まで塗ったら、下半分のほうが上半分より濃くなる。
        let halves = inkHalves(tank(0.5))
        #expect(halves.bottom > halves.top)
        // 空なら上下がほぼそろう（どちらも薄いグリフだけ）。
        let emptyHalves = inkHalves(tank(0))
        #expect(emptyHalves.bottom > 0 && emptyHalves.top > 0)
    }

    @Test func 超過分は満タンで止まる() {
        #expect(abs(ink(tank(2.5)) - ink(tank(1))) < 0.001)
    }
}

/// 追従モード（TF-0080）の明滅。実際の見え方は実機でしか確かめられないが、
/// 「アルファだけを動かしている」ことと「テンプレート可否を変えない」ことはここで押さえる。
struct MenuBarGlowTests {
    private func plain(_ level: BudgetLevel? = nil) -> NSImage {
        MenuBarImage.statusItem(for: content(gauges: seg([0.5], level)))!
    }

    @Test func 帯が通ったところは薄くなる() {
        let base = plain()
        // 位相 0 は帯が画像の下（画面外）にある瞬間なので、元の濃さのまま。
        let start = MenuBarImage.glowing(base, phase: 0)
        let middle = MenuBarImage.glowing(base, phase: 0.5)
        #expect(abs(ink(start) - ink(base)) < 0.001)
        #expect(ink(middle) < ink(base))
        #expect(ink(middle) > 0)   // 消えはしない
    }

    @Test func 位相を進めると濃さが動く() {
        let base = plain()
        let quarter = ink(MenuBarImage.glowing(base, phase: 0.25))
        let middle = ink(MenuBarImage.glowing(base, phase: 0.5))
        #expect(abs(quarter - middle) > 0.001)
    }

    /// 色を足さずアルファだけを動かすので、予算しきい値の色は明滅中も変わらない。
    @Test func テンプレート可否は変えない() {
        #expect(MenuBarImage.glowing(plain(), phase: 0.5).isTemplate == true)
        #expect(MenuBarImage.glowing(plain(.warning), phase: 0.5).isTemplate == false)
    }

    @Test func 読み上げ用の説明を引き継ぐ() {
        let label = "今日の推定コスト: $5.00（50%）"
        let base = MenuBarImage.statusItem(for: content(gauges: seg([0.5]), label: label))!
        #expect(MenuBarImage.glowing(base, phase: 0.5).accessibilityDescription == label)
    }
}

/// ステータス項目 1 個ぶんの画像の組み立て。
struct MenuBarStatusItemImageTests {
    private let oneSide = 1 * MenuBarImage.side
    private var twoSide: CGFloat { MenuBarImage.side * 2 + 3 }

    @Test func ゲージが無ければアイコンだけ() {
        let image = MenuBarImage.statusItem(for: content())
        #expect(image?.size == NSSize(width: oneSide, height: MenuBarImage.side))
    }

    @Test func アイコンを外せばリングだけ() {
        let image = MenuBarImage.statusItem(for: content(showsIcon: false, gauges: seg([0.5])))
        #expect(image?.size == NSSize(width: oneSide, height: MenuBarImage.side))
    }

    @Test func アイコンとリングは横に並べて1枚にする() {
        let both = MenuBarImage.statusItem(for: content(gauges: seg([0.5])))!
        let ringOnly = MenuBarImage.statusItem(for: content(showsIcon: false,
                                                           gauges: seg([0.5])))!
        #expect(both.size.width == twoSide)
        #expect(both.size.height == MenuBarImage.side)
        #expect(ink(both) > ink(ringOnly))
    }

    @Test func タンクは側ごとに1つずつ並べる() {
        let one = MenuBarImage.statusItem(for: content(shape: .tank, gauges: seg([0.5])))!
        let two = MenuBarImage.statusItem(for: content(shape: .tank, gauges: seg([0.5, 0.5])))!
        #expect(one.size.width == oneSide)
        #expect(two.size.width == twoSide)
    }

    @Test func ゲージを描けない指定でもアイコンに戻す() {
        // ここで nil を返すとステータス項目が消えてクリックできなくなる。
        #expect(MenuBarImage.statusItem(for: content(gauges: seg([0.1, 0.2, 0.3]))) != nil)
        #expect(MenuBarImage.statusItem(for: content(showsIcon: false, gauges: [])) != nil)
    }

    @Test func 予算の有無でテンプレート可否が決まる() {
        // 予算があればゲージが色を持つので、画像全体が非テンプレートになる。
        #expect(MenuBarImage.statusItem(for: content(gauges: seg([0.5])))?.isTemplate == true)
        #expect(MenuBarImage.statusItem(for: content(gauges: seg([0.5], .ok)))?
                    .isTemplate == false)
        #expect(MenuBarImage.statusItem(for: content(shape: .tank, gauges: seg([0.5], .over)))?
                    .isTemplate == false)
    }

    /// ゲージなしのアイコンは今までどおり、平常時はテンプレート（無彩色）のまま。
    /// ゲージの青がアイコン単体の見え方まで変えてしまわないことを押さえる。
    @Test func ゲージが無ければ平常時のアイコンは無彩色() {
        #expect(MenuBarImage.statusItem(for: content(iconLevel: .ok))?.isTemplate == true)
        #expect(MenuBarImage.statusItem(for: content(iconLevel: .warning))?.isTemplate == false)
    }

    @Test func 明滅の1コマでも項目が消えない() {
        // nil を返すとステータス項目が消えてクリックできなくなる。位相を一周させて確かめる。
        for phase in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(MenuBarImage.statusItem(for: content(gauges: seg([0.5])),
                                            glowPhase: phase) != nil)
            #expect(MenuBarImage.statusItem(for: content(), glowPhase: phase) != nil)
        }
        // 位相を渡さなければ通常の画像のまま。
        #expect(MenuBarImage.statusItem(for: content(), glowPhase: nil) != nil)
    }

    @Test func 明滅させても寸法は変わらない() {
        let plain = MenuBarImage.statusItem(for: content(gauges: seg([0.5])))!
        let glowing = MenuBarImage.statusItem(for: content(gauges: seg([0.5])), glowPhase: 0.5)!
        #expect(glowing.size == plain.size)
    }

    @Test func 読み上げ用の説明を持たせる() {
        let label = "今日の推定コスト: $5.00（50%）"
        for shape in MenuBarGaugeShape.allCases {
            for showsIcon in [true, false] {
                #expect(MenuBarImage.statusItem(
                    for: content(shape: shape, showsIcon: showsIcon, gauges: seg([0.5]),
                                 label: label))?.accessibilityDescription == label)
            }
        }
        #expect(MenuBarImage.statusItem(for: content(label: label))?
                    .accessibilityDescription == label)
    }
}
