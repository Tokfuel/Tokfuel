import Testing
@testable import TokfuelUI

#if DEBUG

/// `ScreenshotRenderer.screenNames` 全画面のピクセル回帰。
/// E2E は操作・反映、こちらは見た目。`AppSettings.shared` を共有するので直列。
///
/// TestDocs の VRT 完了条件（設定フラグごとの画面パターン）を担保する。
/// 対応シナリオ例: Settings-04/05/06/09/26/36/37、Cost-01/02/12、MenuBar-01/29、
/// Cursor-11/12、Budget-10 など（`App/Tests/TestDocs`）。
@Suite(.serialized)
struct UISnapshotTests {
    @Suite
    struct Popover {
        @Test @MainActor
        func popoverMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover")
        }

        @Test @MainActor
        func lightMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-light")
        }

        @Test @MainActor
        func updateMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-update")
        }

        @Test @MainActor
        func cursorDegradedMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-cursor-degraded")
        }

        @Test @MainActor
        func cursorSigninMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-cursor-signin")
        }

        @Test @MainActor
        func sessionsMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-sessions")
        }

        @Test @MainActor
        func adviceMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-advice")
        }

        @Test @MainActor
        func adviceExpandedMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-advice-expanded")
        }

        @Test @MainActor
        func scrolledMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-scrolled")
        }

        @Test @MainActor
        func moreMenuMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-more-menu")
        }

        @Test @MainActor
        func periodTodayMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-period-today")
        }

        @Test @MainActor
        func periodWeekMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-period-week")
        }

        @Test @MainActor
        func periodMonthMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-period-month")
        }

        @Test @MainActor
        func periodYearMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-period-year")
        }

        @Test @MainActor
        func jpyMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-jpy")
        }

        @Test @MainActor
        func claudeOnlyMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-claude-only")
        }

        @Test @MainActor
        func combinedMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-combined")
        }

        @Test @MainActor
        func cumulativeMatchesReference() throws {
            try SnapshotSupport.assertScreen("popover-cumulative")
        }
    }

    @Suite
    struct Settings {
        @Test @MainActor
        func settingsMatchesReference() throws {
            try SnapshotSupport.assertScreen("settings")
        }

        @Test @MainActor
        func jpyMatchesReference() throws {
            try SnapshotSupport.assertScreen("settings-jpy")
        }

        @Test @MainActor
        func claudeOnlyMatchesReference() throws {
            try SnapshotSupport.assertScreen("settings-claude-only")
        }

        @Test @MainActor
        func advancedMatchesReference() throws {
            try SnapshotSupport.assertScreen("settings-advanced")
        }

        @Test @MainActor
        func debugMatchesReference() throws {
            try SnapshotSupport.assertScreen("settings-debug")
        }
    }

    @Suite
    struct Dialogs {
        @Test @MainActor
        func aboutMatchesReference() throws {
            try SnapshotSupport.assertScreen("about")
        }

        @Test @MainActor
        func budgetAlertMatchesReference() throws {
            try SnapshotSupport.assertScreen("budget-alert")
        }

        @Test @MainActor
        func analyticsConsentMatchesReference() throws {
            try SnapshotSupport.assertScreen("analytics-consent")
        }
    }

    @Test @MainActor
    func screenNamesStayInSync() {
        #expect(ScreenshotRenderer.screenNames.count == 26)
        #expect(Set(ScreenshotRenderer.screenNames).count == 26)
    }
}

#endif
