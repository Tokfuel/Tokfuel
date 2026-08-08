import Testing
@testable import TokfuelUI

#if DEBUG

/// ホーム（popover）フィクスチャのピクセル回帰。E2E は操作・反映、こちらは見た目。
@Suite(.serialized)
struct PopoverSnapshotTests {
    @Test @MainActor
    func popoverMatchesReference() throws {
        try SnapshotSupport.assertScreen("popover")
    }
}

/// 設定画面フィクスチャのピクセル回帰。
@Suite(.serialized)
struct SettingsSnapshotTests {
    @Test @MainActor
    func settingsMatchesReference() throws {
        try SnapshotSupport.assertScreen("settings")
    }
}

#endif
