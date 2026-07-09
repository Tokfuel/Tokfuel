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

// --- 白いバーチャート ---
func bar(_ x: CGFloat, _ height: CGFloat, width: CGFloat, baseTop: CGFloat, alpha: CGFloat = 1) {
    let r = CGRect(x: x, y: baseTop, width: width, height: height)
    let p = CGPath(roundedRect: r, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.addPath(p)
    ctx.setFillColor(CGColor(gray: 1, alpha: alpha))
    ctx.fillPath()
}

let barWidth: CGFloat = 120
let gap: CGFloat = 62
let startX: CGFloat = 270
let baseTop: CGFloat = 360        // バーの下端
// ベースライン
let baseRect = CGRect(x: startX, y: 320, width: barWidth * 3 + gap * 2, height: 30)
ctx.addPath(CGPath(roundedRect: baseRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
ctx.fillPath()
// 3 本の昇順バー
bar(startX, 150, width: barWidth, baseTop: baseTop)
bar(startX + (barWidth + gap), 250, width: barWidth, baseTop: baseTop)
bar(startX + (barWidth + gap) * 2, 360, width: barWidth, baseTop: baseTop)

NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
