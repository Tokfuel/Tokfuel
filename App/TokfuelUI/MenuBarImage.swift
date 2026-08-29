import AppKit
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

func menuBarAlertColor(for level: BudgetLevel) -> NSColor? {
    switch level {
    case .ok: return nil
    case .warning: return .systemOrange
    case .over: return .systemRed
    }
}

func menuBarRingColor(for level: BudgetLevel) -> NSColor {
    switch level {
    case .ok: return .systemBlue
    case .warning: return .systemOrange
    case .over: return .systemRed
    }
}

public enum MenuBarImage {
    public static let side: CGFloat = 16
    private static let gap: CGFloat = 3

    private static let single: [(radius: CGFloat, width: CGFloat)] = [(5.7, 2.2)]
    private static let double: [(radius: CGFloat, width: CGFloat)] = [(3.2, 1.7), (6.3, 1.7)]

    /// 追従モードの明滅で 1 周期に使う秒数。
    public static let glowCycle: TimeInterval = 2
    public static let glowFrameInterval: TimeInterval = 1.0 / 12
    private static let glowMinAlpha: CGFloat = 0.35
    private static let glowBandRatio: CGFloat = 0.7

    public static func statusItem(for content: MenuBarContent, glowPhase: Double?) -> NSImage? {
        guard let image = statusItem(for: content) else { return nil }
        guard let glowPhase else { return image }
        return glowing(image, phase: glowPhase)
    }

    /// 色を足さずアルファだけを動かすのは、予算しきい値の色をそのまま活かすため。
    /// テンプレート画像（平常時のアイコン）はアルファだけが意味を持つので、この方式ならメニューバーの
    /// 明暗への追従も壊さずに済む。
    public static func glowing(_ base: NSImage, phase: Double) -> NSImage {
        let size = base.size
        let cycle = min(max(phase, 0), 1)
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            let band = rect.height * glowBandRatio
            let travel = rect.height + band
            let originY = rect.minY - band + travel * CGFloat(cycle)
            let bandRect = NSRect(x: rect.minX, y: originY, width: rect.width, height: band)
            // destinationIn は「塗った矩形の中だけ」を転送先のアルファに掛ける。帯の外側は触らないので、
            // 通り過ぎたところは元の濃さに戻る。
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

    public static func statusItem(for content: MenuBarContent) -> NSImage? {
        let label = content.toolTip
        let gauges = content.gauges
        guard !gauges.isEmpty else {
            return fuelpump(tint: content.iconLevel.flatMap { menuBarAlertColor(for: $0) }, label: label)
        }
        // 予算が 1 つも無ければ示す基準が無いので、テンプレート描画で明暗に追従させる。
        let template = gauges.allSatisfy { $0.level == nil }

        let parts: [NSImage]
        switch content.shape {
        case .tank:
            parts = gauges.map { tank($0, template: template) }
        case .ring:
            guard let ring = ring(gauges, template: template) else {
                return fuelpump(tint: content.iconLevel.flatMap { menuBarAlertColor(for: $0) }, label: label)
            }
            // 明暗に追従させることはできないので、併記するアイコンも同じ配色で塗る
            let iconTint = template ? nil : content.iconLevel.map { menuBarRingColor(for: $0) } ?? neutral
            parts = content.showsIcon
                ? [fuelpump(tint: iconTint, label: label), ring].compactMap { $0 }
                : [ring]
        }
        guard let image = compose(parts) else { return nil }
        image.isTemplate = template
        image.accessibilityDescription = label
        return image
    }

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

    public static func tank(_ gauge: MenuBarGaugeSegment, template: Bool) -> NSImage {
        let filled: NSColor = template ? .black : (gauge.level.map { menuBarRingColor(for: $0) } ?? neutral)
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

    public static func fuelpump(tint: NSColor?, label: String = "Tokfuel") -> NSImage? {
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

    /// 弧は側ごとに色を持つので、今日だけしきい値を越えたときは内側だけが変わる。
    public static func ring(_ gauges: [MenuBarGaugeSegment], template: Bool) -> NSImage? {
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
                let color: NSColor = template
                    ? .black : (gauge.level.map { menuBarRingColor(for: $0) } ?? neutral)
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

    /// テンプレート描画ではアルファだけが意味を持つので、黒を薄めれば OS が明暗に合わせて
    /// 塗り替えてくれる。色付きの画像は明暗に追従しないため、半透明の色は背景と混ざって
    /// ほぼ見えなくなる。そこで色付きのときは明暗どちらでも沈まない中間グレーを使う。
    private static func trackColor(colored: Bool) -> NSColor {
        colored ? NSColor(white: 0.55, alpha: 0.65) : NSColor(white: 0, alpha: 0.35)
    }

    private static func strokeTrack(center: CGPoint, radius: CGFloat, width: CGFloat,
                                    color: NSColor) {
        let box = CGRect(x: center.x - radius, y: center.y - radius,
                         width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: box)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

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
