import AppKit
import Foundation
import SnapshotTesting
import Testing
@testable import TokfuelUI

#if DEBUG

/// Point-Free SnapshotTesting 向けの薄いヘルパー。
/// 描画は `ScreenshotRenderer`（NSHostingView 実描画）に任せ、SwiftUI 直の `.image` は使わない。
enum SnapshotSupport {
    /// 本体のみキャンバス（popover 360×520 等）向け。デスクトップ合成時代は 0.99 でも
    /// ヒーロー金額級の差分が 1% 未満に薄まって通っていた。0.995 なら約 0.87% の
    /// 金額差し替え（$16.54→$999.99）を落とせる。CI 正本との AA 差はまだ吸収する。
    static let imagePrecision: Float = 0.995
    static let perceptualPrecision: Float = 0.98

    @MainActor
    static func assertScreen(
        _ name: String,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) throws {
        let data = try ScreenshotRenderer.pngData(named: name)
        let image = try #require(NSImage(data: data))
        assertSnapshot(
            of: image,
            as: .image(
                precision: imagePrecision,
                perceptualPrecision: perceptualPrecision
            ),
            named: name,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

#endif
