// アプリアイコンの .iconset / .icns を生成する。
//
//     swift assets/make-icon.swift
//
// デザインの正本はこのリポジトリではなく Icon Composer ドキュメント
// （https://github.com/Tokfuel/icon の Tokfuel.icon）。ここでの仕事は、
// そこから書き出した icon-master.png を macOS のアイコングリッドに収めて
// 各サイズに焼くところまでで、絵そのものは一切描かない。
import AppKit

let assetsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let masterURL = assetsDir.appendingPathComponent("icon-master.png")
let iconsetURL = assetsDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = assetsDir.appendingPathComponent("AppIcon.icns")

guard let master = NSImage(contentsOf: masterURL) else {
    fatalError("cannot read \(masterURL.path)")
}

// Icon Composer の書き出しはスクィルカルがキャンバスいっぱいに広がるフルブリード。
// macOS 14 / 15 の Dock は Apple のアイコングリッド（1024 のキャンバスに 824 の
// アート）を前提に並べるので、そのまま焼くと隣のアプリより一段大きく見える。
// 同じ比率で内側に寄せてから各サイズを作る。
let artRatio: CGFloat = 824.0 / 1024.0

/// マスターを `canvas` px 四方の透明キャンバス中央に `artRatio` で描いた PNG を返す。
func renderPNG(canvas: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        fatalError("cannot allocate \(canvas)px bitmap")
    }
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // 16px まで縮めるので、既定の補間だと輪郭がざらつく。
    NSGraphicsContext.current?.imageInterpolation = .high

    // 余白を先に整数へ丸めてから辺を決める。辺を丸めると 16px などで余白が
    // 左右 1px ずれ、輪郭がにじむ。
    let inset = (CGFloat(canvas) * (1 - artRatio) / 2).rounded()
    let side = CGFloat(canvas) - inset * 2
    master.draw(in: NSRect(x: inset, y: inset, width: side, height: side))

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(canvas)px PNG")
    }
    return data
}

// iconutil が要求する 10 エントリ（論理サイズ, 倍率）。
let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for entry in entries {
    let suffix = entry.scale == 1 ? "" : "@\(entry.scale)x"
    let name = "icon_\(entry.points)x\(entry.points)\(suffix).png"
    let data = renderPNG(canvas: entry.points * entry.scale)
    try data.write(to: iconsetURL.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

print("wrote \(iconsetURL.lastPathComponent) and \(icnsURL.lastPathComponent)")
