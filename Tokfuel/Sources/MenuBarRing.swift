import AppKit

extension BudgetLevel {
    /// メニューバーで注意を促す色。ok は色を持たず、テンプレート描画（明暗に追従する単色）に任せる。
    /// 給油機アイコンとリングで同じ配色になるよう、両者はここを通す。
    var menuBarAlertColor: NSColor? {
        switch self {
        case .ok: return nil
        case .warning: return .systemOrange
        case .over: return .systemRed
        }
    }
}

/// メニューバーのリングゲージを NSImage として描く。塗り分率の算出は MenuBarReadout 側で、
/// ここは受け取った 0...1 を絵にするだけ。
enum MenuBarRing {
    /// メニューバーのアイコン寸法。給油機アイコンと入れ替えて使うのでそろえる。
    static let side: CGFloat = 16

    /// 弧の太さと半径。1 本なら大きく、2 本なら外（月次）と内（日次）に分ける。
    private static let single: [(radius: CGFloat, width: CGFloat)] = [(5.7, 2.2)]
    private static let double: [(radius: CGFloat, width: CGFloat)] = [(3.2, 1.7), (6.3, 1.7)]

    /// `fills` は MenuBarContent と同じ順（先頭 = 内側 / 日次）。本数が想定外なら nil。
    /// `level` が nil のときはテンプレート描画にして、メニューバーの明暗に追従させる。
    /// 色は弧ごとに変えない。色付きと無色が混ざると、非テンプレート画像になった無色側が
    /// 明暗に追従できず、暗いメニューバーで見えなくなる。
    static func image(_ fills: [Double], level: BudgetLevel?, label: String) -> NSImage? {
        let geometry: [(radius: CGFloat, width: CGFloat)]
        switch fills.count {
        case 1: geometry = single
        case 2: geometry = double
        default: return nil
        }
        let rings = Array(zip(fills, geometry))
        let alertColor = level?.menuBarAlertColor
        // テンプレート描画は黒（アルファ）で描いた絵を OS が塗り直すため、無色は黒で描く。
        let color = alertColor ?? .black

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for (fill, shape) in rings {
                // トラックは同じ色を薄くしたもの。
                strokeTrack(center: center, radius: shape.radius, width: shape.width,
                            color: color.withAlphaComponent(0.25))
                let clamped = min(max(fill, 0), 1)
                if clamped > 0 {
                    strokeArc(center: center, radius: shape.radius, width: shape.width,
                              fraction: clamped, color: color)
                }
            }
            return true
        }
        image.isTemplate = alertColor == nil
        image.accessibilityDescription = label
        return image
    }

    /// 満タンぶんの下地。円弧を 360° 引くと始端・終端の丸キャップが重なるので円で描く。
    private static func strokeTrack(center: CGPoint, radius: CGFloat, width: CGFloat,
                                    color: NSColor) {
        let box = CGRect(x: center.x - radius, y: center.y - radius,
                         width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: box)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    /// 12 時から時計回りに `fraction` 分だけ弧を引く。
    private static func strokeArc(center: CGPoint, radius: CGFloat, width: CGFloat,
                                  fraction: Double, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius,
                       startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
}
