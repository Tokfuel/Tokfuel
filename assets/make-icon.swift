import AppKit
import CoreGraphics

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("rep")
}
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func clay(_ hex: (CGFloat, CGFloat, CGFloat)) -> CGColor {
    CGColor(red: hex.0/255, green: hex.1/255, blue: hex.2/255, alpha: 1)
}
let top = clay((232, 146, 124))     // #E8927C
let bottom = clay((217, 119, 87))   // #D97757

// --- 角丸のクレイ色スクエア（macOS 風のスクィルカル） ---
let inset: CGFloat = 90
let square = CGRect(x: inset, y: inset, width: CGFloat(size) - inset * 2,
                    height: CGFloat(size) - inset * 2)
let corner: CGFloat = 190
let squarePath = CGPath(roundedRect: square, cornerWidth: corner, cornerHeight: corner,
                        transform: nil)

// 影で立体感
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34,
              color: CGColor(gray: 0, alpha: 0.28))
ctx.addPath(squarePath)
ctx.setFillColor(bottom)
ctx.fillPath()
ctx.restoreGState()

// グラデーション塗り（上→下）
ctx.saveGState()
ctx.addPath(squarePath)
ctx.clip()
let space = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: square.maxY),
                       end: CGPoint(x: 0, y: square.minY), options: [])
// 上部の淡いハイライト
let sheen = CGGradient(colorsSpace: space,
                       colors: [CGColor(gray: 1, alpha: 0.18),
                                CGColor(gray: 1, alpha: 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: square.maxY),
                       end: CGPoint(x: 0, y: square.midY + 60), options: [])
ctx.restoreGState()

// --- 白い燃料ポンプ（SF Symbol） ---
let config = NSImage.SymbolConfiguration(pointSize: 480, weight: .medium)
    .applying(.init(paletteColors: [.white]))
guard let pump = NSImage(systemSymbolName: "fuelpump.fill",
                         accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else { fatalError("symbol") }

// シンボルのアスペクト比を保ったまま、スクエア中央に収める。
let maxSide: CGFloat = 540
let scale = min(maxSide / pump.size.width, maxSide / pump.size.height)
let drawSize = NSSize(width: pump.size.width * scale, height: pump.size.height * scale)
let drawRect = NSRect(x: (CGFloat(size) - drawSize.width) / 2,
                      y: (CGFloat(size) - drawSize.height) / 2,
                      width: drawSize.width, height: drawSize.height)
pump.draw(in: drawRect)

NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
