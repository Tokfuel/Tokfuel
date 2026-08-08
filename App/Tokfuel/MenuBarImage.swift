import AppKit

extension BudgetLevel {
    /// 給油機アイコン単体の色。ok は色を持たず、テンプレート描画（明暗に追従する単色）に任せる。
    /// 平常時のメニューバーを静かに保ち、注意が必要なときだけ色で知らせる。
    var menuBarAlertColor: NSColor? {
        switch self {
        case .ok: return nil
        case .warning: return .systemOrange
        case .over: return .systemRed
        }
    }

    /// リングゲージの色。ゲージは「どこまで使ったか」を常に示すものなので、
    /// 平常時も無色にはせず青を置き、しきい値でオレンジ、超過で赤に上げる。
    var menuBarRingColor: NSColor {
        switch self {
        case .ok: return .systemBlue
        case .warning: return .systemOrange
        case .over: return .systemRed
        }
    }
}

/// ステータス項目に出す画像を組み立てる。給油機アイコンとリングゲージを、設定に応じて
/// 単独または横並びの 1 枚にする。塗り分率の算出は MenuBarReadout 側の仕事。
enum MenuBarImage {
    /// アイコン 1 つぶんの寸法。
    static let side: CGFloat = 16
    /// アイコンとリングを並べるときの間隔。
    private static let gap: CGFloat = 3

    /// 弧の太さと半径。1 本なら大きく、2 本なら外（月次）と内（日次）に分ける。
    private static let single: [(radius: CGFloat, width: CGFloat)] = [(5.7, 2.2)]
    private static let double: [(radius: CGFloat, width: CGFloat)] = [(3.2, 1.7), (6.3, 1.7)]

    /// 追従モード（TF-0080）の明滅で 1 周期に使う秒数。
    static let glowCycle: TimeInterval = 2
    /// 明滅の 1 コマの間隔（秒）。12 fps 相当。
    static let glowFrameInterval: TimeInterval = 1.0 / 12
    /// 明滅の帯が通ったところの最小不透明度。0 にすると帯の位置でアイコンが消える。
    private static let glowMinAlpha: CGFloat = 0.35
    /// 明滅の帯の高さ（アイコン高さに対する比）。
    private static let glowBandRatio: CGFloat = 0.7

    /// ステータス項目の画像。`glowPhase`（0…1）を渡すと、追従モードを示す帯が
    /// 下から上へ流れる 1 コマを描く（nil なら通常の画像）。
    static func statusItem(for content: MenuBarContent, glowPhase: Double?) -> NSImage? {
        guard let image = statusItem(for: content) else { return nil }
        guard let glowPhase else { return image }
        return glowing(image, phase: glowPhase)
    }

    /// アイコンの上を「液体が流れる」ように、半透明の帯を 1 本通した 1 コマ。
    ///
    /// 色を足さずアルファだけを動かすのは、予算しきい値の色（`combinedBudgetLevel`）を
    /// そのまま活かすため。警告中はオレンジ、超過中は赤のまま明滅する。テンプレート画像
    /// （平常時のアイコン）はアルファだけが意味を持つので、この方式ならメニューバーの
    /// 明暗への追従も壊さずに済む。
    static func glowing(_ base: NSImage, phase: Double) -> NSImage {
        let size = base.size
        let cycle = min(max(phase, 0), 1)
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            // 帯は画像の下（画面外）から上（画面外）へ 1 周期で通り抜ける。
            let band = rect.height * glowBandRatio
            let travel = rect.height + band
            let originY = rect.minY - band + travel * CGFloat(cycle)
            let bandRect = NSRect(x: rect.minX, y: originY, width: rect.width, height: band)
            // destinationIn は「塗った矩形の中だけ」転送先のアルファに source のアルファを
            // 掛ける。帯の外側は触らないので、通り過ぎたところは元の濃さに戻る。
            let opaque = NSColor(white: 0, alpha: 1)
            let gradient = NSGradient(colors: [opaque,
                                               NSColor(white: 0, alpha: glowMinAlpha),
                                               opaque])
            NSGraphicsContext.current?.compositingOperation = .destinationIn
            gradient?.draw(in: bandRect, angle: 90)
            return true
        }
        image.isTemplate = base.isTemplate
        image.accessibilityDescription = base.accessibilityDescription
        return image
    }

    /// ステータス項目の画像。ゲージが無ければアイコンだけ、あれば形に応じて組み立てる。
    /// ゲージを描けない指定でも、項目が消えないようアイコンにフォールバックする。
    static func statusItem(for content: MenuBarContent) -> NSImage? {
        let label = content.toolTip
        let gauges = content.gauges
        guard !gauges.isEmpty else {
            return fuelpump(tint: content.iconLevel?.menuBarAlertColor, label: label)
        }
        // 予算が 1 つも無ければ示す基準が無いので、テンプレート描画で明暗に追従させる。
        let template = gauges.allSatisfy { $0.level == nil }

        let parts: [NSImage]
        switch content.shape {
        case .tank:
            // 給油機そのものが燃料計。側ごとに 1 つずつ並べる。
            parts = gauges.map { tank($0, template: template) }
        case .ring:
            guard let ring = ring(gauges, template: template) else {
                return fuelpump(tint: content.iconLevel?.menuBarAlertColor, label: label)
            }
            // リングに色が付くと画像全体が非テンプレートになる。1 枚の画像の中で片方だけを
            // 明暗に追従させることはできないので、併記するアイコンも同じ配色で塗る
            // （テンプレート用の黒のまま重ねると、暗いメニューバーでアイコンが消える）。
            let iconTint = template ? nil : content.iconLevel?.menuBarRingColor ?? neutral
            parts = content.showsIcon
                ? [fuelpump(tint: iconTint, label: label), ring].compactMap { $0 }
                : [ring]
        }
        guard let image = compose(parts) else { return nil }
        image.isTemplate = template
        image.accessibilityDescription = label
        return image
    }

    /// 画像を横に並べて 1 枚にする。1 枚だけならそのまま返す。
    private static func compose(_ parts: [NSImage]) -> NSImage? {
        guard let first = parts.first else { return nil }
        guard parts.count > 1 else { return first }
        let width = side * CGFloat(parts.count) + gap * CGFloat(parts.count - 1)
        return NSImage(size: NSSize(width: width, height: side), flipped: false) { _ in
            for (i, part) in parts.enumerated() {
                part.draw(in: NSRect(x: (side + gap) * CGFloat(i), y: 0,
                                     width: side, height: side))
            }
            return true
        }
    }

    /// 給油機アイコンを下から `fill` 分だけ塗り上げた燃料計。
    /// グリフのアルファを型にして、下側だけ濃い色で塗り替える。
    static func tank(_ gauge: MenuBarGaugeSegment, template: Bool) -> NSImage {
        let filled: NSColor = template ? .black : (gauge.level?.menuBarRingColor ?? neutral)
        // 未消費ぶん。テンプレートならアルファで薄め、色付きなら明暗に沈まないグレー。
        let empty: NSColor = template ? NSColor(white: 0, alpha: 0.3) : trackColor(colored: true)
        let level = min(max(gauge.fill, 0), 1)
        let glyph = NSImage(systemSymbolName: "fuelpump.fill", accessibilityDescription: nil)
        glyph?.size = NSSize(width: side, height: side)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            glyph?.draw(in: rect)
            // sourceIn は「塗った矩形の中だけ」を転送先のアルファに掛ける。掛け算なので
            // 一度薄くした上を濃く塗り直しても戻らない。下側と上側を 1 回ずつ塗り分ける。
            let split = rect.minY + rect.height * level
            if level > 0 {
                filled.set()
                NSRect(x: rect.minX, y: rect.minY,
                       width: rect.width, height: split - rect.minY).fill(using: .sourceIn)
            }
            if level < 1 {
                empty.set()
                NSRect(x: rect.minX, y: split,
                       width: rect.width, height: rect.maxY - split).fill(using: .sourceIn)
            }
            return true
        }
    }

    /// 給油機アイコン。`tint` が nil ならテンプレート描画（メニューバーの明暗に追従）。
    static func fuelpump(tint: NSColor?, label: String = "Tokfuel") -> NSImage? {
        let base = NSImage(systemSymbolName: "fuelpump.fill", accessibilityDescription: label)
        let image: NSImage?
        if let tint {
            image = base?.withSymbolConfiguration(.init(paletteColors: [tint]))
            image?.isTemplate = false
        } else {
            image = base   // テンプレート描画（メニューバーの明暗に追従）
        }
        image?.size = NSSize(width: side, height: side)
        return image
    }

    /// `gauges` は MenuBarContent と同じ順（先頭 = 内側 / 今日）。本数が想定外なら nil。
    /// 弧は側ごとに色を持つので、今日だけしきい値を越えたときは内側だけが変わる。
    /// 予算がある側は 青 → オレンジ → 赤、無い側は明暗に沈まないグレー。
    static func ring(_ gauges: [MenuBarGaugeSegment], template: Bool) -> NSImage? {
        let geometry: [(radius: CGFloat, width: CGFloat)]
        switch gauges.count {
        case 1: geometry = single
        case 2: geometry = double
        default: return nil
        }
        let rings = Array(zip(gauges, geometry))
        let track = trackColor(colored: !template)

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for (gauge, shape) in rings {
                // テンプレート描画は黒（アルファ）で描いた絵を OS が塗り直すため黒で描く。
                let color: NSColor = template
                    ? .black : (gauge.level?.menuBarRingColor ?? neutral)
                strokeTrack(center: center, radius: shape.radius, width: shape.width, color: track)
                let clamped = min(max(gauge.fill, 0), 1)
                if clamped > 0 {
                    strokeArc(center: center, radius: shape.radius, width: shape.width,
                              fraction: clamped, color: color)
                }
            }
            return true
        }
        image.isTemplate = template
        return image
    }

    /// 予算が無い側の色。色付き画像に混ざるので、明暗どちらでも沈まない濃さにする。
    private static let neutral = NSColor(white: 0.62, alpha: 1)

    /// 未消費ぶんを示すトラックの色。
    ///
    /// テンプレート描画ではアルファだけが意味を持つので、黒を薄めれば OS が明暗に合わせて
    /// 塗り替えてくれる。一方、色付きの画像は明暗に追従しないため、リング色を薄める方式は
    /// 破綻する。暗いメニューバーでは半透明の色が背景と混ざってほぼ黒くなり、残量が
    /// 読めなくなる。そこで色付きのときは、明暗どちらでも沈まない中間グレーを使う。
    private static func trackColor(colored: Bool) -> NSColor {
        colored ? NSColor(white: 0.55, alpha: 0.65) : NSColor(white: 0, alpha: 0.35)
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
