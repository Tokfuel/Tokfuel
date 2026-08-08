import AppKit
import Foundation
import SnapshotTesting
import Testing
@testable import TokfuelUI

#if DEBUG

/// Point-Free SnapshotTesting 向けの薄いヘルパー。
/// 描画は `ScreenshotRenderer`（NSHostingView 実描画）に任せ、SwiftUI 直の `.image` は使わない。
enum SnapshotSupport {
    /// CI（macos-15）とローカルのフォント AA 差を吸収する。レイアウト崩れはサイズ差や
    /// 大きな画素差でまだ落ちる。参考画像の正本は CI 録音とする。
    static let imagePrecision: Float = 0.99
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
