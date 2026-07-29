import AppKit
import Testing
@testable import Tokfuel

/// リングの見た目そのものは実機で確かめるしかないが、「描けているか」はここで押さえる。
/// 塗りが 0 本・想定外の本数のときに nil を返すことは、ステータス項目が
/// アイコンを失わない（給油機に戻せる）ための前提になる。
struct MenuBarRingTests {
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

    @Test func 描ける本数は1本と2本だけ() {
        #expect(MenuBarRing.image([], level: nil, label: "") == nil)
        #expect(MenuBarRing.image([0.5, 0.5, 0.5], level: nil, label: "") == nil)
        #expect(MenuBarRing.image([0.5], level: nil, label: "") != nil)
        #expect(MenuBarRing.image([0.5, 0.5], level: nil, label: "") != nil)
    }

    @Test func メニューバーのアイコン寸法で描く() {
        let image = MenuBarRing.image([0.5], level: nil, label: "")
        #expect(image?.size == NSSize(width: MenuBarRing.side, height: MenuBarRing.side))
    }

    @Test func 注意色が無ければテンプレート描画にする() {
        // テンプレートでないと、メニューバーが明色のとき黒い絵がそのまま出てしまう。
        #expect(MenuBarRing.image([0.5], level: nil, label: "")?.isTemplate == true)
        #expect(MenuBarRing.image([0.5], level: .ok, label: "")?.isTemplate == true)
        #expect(MenuBarRing.image([0.5], level: .warning, label: "")?.isTemplate == false)
        #expect(MenuBarRing.image([0.5], level: .over, label: "")?.isTemplate == false)
    }

    @Test func 塗りが0でもトラックは描く() {
        // 「使っていない」ことが空のリングとして見えるように、下地は常に出す。
        #expect(ink(MenuBarRing.image([0], level: nil, label: "")!) > 0)
    }

    @Test func 塗りが増えるとインクも濃くなる() {
        let empty = ink(MenuBarRing.image([0], level: nil, label: "")!)
        let quarter = ink(MenuBarRing.image([0.25], level: nil, label: "")!)
        let full = ink(MenuBarRing.image([1], level: nil, label: "")!)
        #expect(quarter > empty)
        #expect(full > quarter)
    }

    @Test func 超過分は満タンで止まる() {
        // クランプが効いていないと弧が二周ぶん引かれて濃さが変わる。
        let full = ink(MenuBarRing.image([1], level: nil, label: "")!)
        let over = ink(MenuBarRing.image([2.5], level: nil, label: "")!)
        #expect(abs(over - full) < 0.001)
    }

    @Test func 二重リングは単一より多く描く() {
        let single = ink(MenuBarRing.image([1], level: nil, label: "")!)
        let double = ink(MenuBarRing.image([1, 1], level: nil, label: "")!)
        #expect(double > single)
    }

    @Test func 読み上げ用の説明を持たせる() {
        #expect(MenuBarRing.image([0.5], level: nil, label: "今日の推定コスト: $5.00（50%）")?
                    .accessibilityDescription == "今日の推定コスト: $5.00（50%）")
    }
}
