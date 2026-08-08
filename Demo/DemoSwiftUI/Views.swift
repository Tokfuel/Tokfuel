import JavaScriptKit

/// Local TokamakDOM-shaped host for DemoUI.
/// Upstream Tokamak is the intended backend once Swift 6.2 wasip1 builds cleanly.

public final class DemoRenderScheduler {
    public static let shared = DemoRenderScheduler()
    public var onRender: (() -> Void)?
    public func requestRender() { onRender?() }
}

public enum DemoNode {
    case text(String, style: TextStyle = .body)
    case button(String, id: String, style: TextStyle = .body)
    case vstack([DemoNode], spacing: Double = 8, padding: Double = 0)
    case hstack([DemoNode], spacing: Double = 8)
    case spacer
    case divider
    case scroll([DemoNode])
    case bar(widthFraction: Double, color: String, height: Double = 5)
    case stackedBar(claudeFraction: Double, cursorFraction: Double, height: Double)
    case frame([DemoNode], minWidth: Double? = nil, minHeight: Double? = nil, background: String? = nil, radius: Double = 0)
}

public enum TextStyle {
    case hero
    case caption
    case body
    case secondary
    case headline
    case title
    case tiny

    var css: String {
        switch self {
        case .hero: return "font-size:34px;font-weight:700;letter-spacing:-0.03em;font-family:ui-rounded,system-ui,sans-serif;"
        case .caption: return "font-size:11px;color:rgba(235,235,245,0.6);"
        case .body: return "font-size:13px;color:#f5f5f7;"
        case .secondary: return "font-size:11px;color:rgba(235,235,245,0.6);"
        case .headline: return "font-size:15px;font-weight:600;color:#f5f5f7;"
        case .title: return "font-size:22px;font-weight:700;color:#f5f5f7;"
        case .tiny: return "font-size:9px;color:rgba(235,235,245,0.6);"
        }
    }
}

public enum DemoHTML {
    public static func encode(_ node: DemoNode) -> String {
        switch node {
        case let .text(value, style):
            return "<div style=\"\(style.css)\">\(escape(value))</div>"
        case let .button(title, id, style):
            return "<button type=\"button\" data-action=\"\(escape(id))\" style=\"\(style.css)appearance:none;border:0;background:transparent;cursor:pointer;padding:4px 6px;border-radius:6px;\">\(escape(title))</button>"
        case let .vstack(children, spacing, padding):
            let inner = children.map(encode).joined()
            return "<div style=\"display:flex;flex-direction:column;align-items:stretch;gap:\(spacing)px;padding:\(padding)px;\">\(inner)</div>"
        case let .hstack(children, spacing):
            let inner = children.map(encode).joined()
            return "<div style=\"display:flex;flex-direction:row;align-items:center;gap:\(spacing)px;width:100%;\">\(inner)</div>"
        case .spacer:
            return "<div style=\"flex:1 1 auto;\"></div>"
        case .divider:
            return "<div style=\"height:1px;background:rgba(255,255,255,0.08);width:100%;\"></div>"
        case let .scroll(children):
            let inner = children.map(encode).joined()
            return "<div style=\"flex:1;overflow:auto;padding:14px 16px;\">\(inner)</div>"
        case let .bar(fraction, color, height):
            let width = max(0, min(1, fraction)) * 100
            return "<div style=\"height:\(height)px;border-radius:999px;background:rgba(118,118,128,0.24);overflow:hidden;\"><div style=\"height:100%;width:\(width)%;background:\(color);border-radius:999px;\"></div></div>"
        case let .stackedBar(claude, cursor, height):
            return "<div style=\"display:flex;flex-direction:column-reverse;width:100%;height:\(height)px;border-radius:3px 3px 0 0;overflow:hidden;\"><div style=\"height:\(claude * 100)%;background:#ff9500;\"></div><div style=\"height:\(cursor * 100)%;background:rgba(142,142,147,0.95);\"></div></div>"
        case let .frame(children, minWidth, minHeight, background, radius):
            var style = "display:flex;flex-direction:column;overflow:hidden;"
            if let minWidth { style += "min-width:\(minWidth)px;" }
            if let minHeight { style += "min-height:\(minHeight)px;height:\(minHeight)px;" }
            if let background { style += "background:\(background);" }
            if radius > 0 { style += "border-radius:\(radius)px;border:1px solid rgba(255,255,255,0.1);" }
            return "<div style=\"\(style)\">\(children.map(encode).joined())</div>"
        }
    }

    public static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }
}

public enum DemoDOM {
    public static func mount(elementID: String = "app", tree: @escaping () -> DemoNode, onAction: @escaping (String) -> Void) {
        let document = JSObject.global.document
        guard let host = document.getElementById(elementID).object else { return }

        let paint: () -> Void = {
            host.innerHTML = .string(DemoHTML.encode(tree()))
            let buttons = host.querySelectorAll!("[data-action]")
            let length = Int(buttons.length.number ?? 0)
            for index in 0..<length {
                guard let button = buttons[index].object else { continue }
                let action = button.getAttribute!("data-action").string ?? ""
                let closure = JSClosure { _ in
                    onAction(action)
                    return .undefined
                }
                _ = button.addEventListener!("click", closure)
                _ = Unmanaged.passRetained(closure)
            }
        }

        DemoRenderScheduler.shared.onRender = paint
        paint()
    }
}
