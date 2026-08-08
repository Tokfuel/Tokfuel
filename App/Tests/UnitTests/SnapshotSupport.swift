import AppKit
import Foundation
import SnapshotTesting
import Testing
@testable import TokfuelUI

#if DEBUG

/// Point-Free SnapshotTesting 向けの薄いヘルパー。
/// 描画は `ScreenshotRenderer`（NSHostingView 実描画）に任せ、SwiftUI 直の `.image` は使わない。
enum SnapshotSupport {
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
            as: .image,
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
