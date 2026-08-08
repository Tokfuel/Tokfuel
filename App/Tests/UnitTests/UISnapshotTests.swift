import Foundation
import Testing
@testable import TokfuelUI

#if DEBUG

/// `ScreenshotRenderer.screenNames` 全画面のピクセル回帰。
/// E2E は操作・反映、こちらは見た目。`AppSettings.shared` を共有するので直列。
///
/// 画面名 ↔ TestDocs 観点 ID は `VRTScreenMap`（表は `App/Tests/TestDocs/VRT_SCREENS.md`）。
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

    @Test @MainActor
    func everyScreenMapsToViewpointIDs() {
        let mapped = Set(VRTScreenMap.screensToViewpointIDs.keys)
        let screens = Set(ScreenshotRenderer.screenNames)
        #expect(mapped == screens)
        for name in ScreenshotRenderer.screenNames {
            #expect(!VRTScreenMap.viewpointIDs(forScreen: name).isEmpty)
        }
    }

    @Test
    func mappedViewpointIDsHaveScenarioFiles() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UnitTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("TestDocs", isDirectory: true)
        for (screen, ids) in VRTScreenMap.screensToViewpointIDs {
            for id in ids {
                let parts = id.split(separator: "-", maxSplits: 2).map(String.init)
                #expect(parts.count == 3, "bad id \(id) for \(screen)")
                let domain = parts[0]
                let nn = parts[1]
                let slug = parts[2]
                let file = root
                    .appendingPathComponent(domain, isDirectory: true)
                    .appendingPathComponent("\(nn)-\(slug).md")
                #expect(
                    FileManager.default.fileExists(atPath: file.path),
                    "missing \(file.path) for screen \(screen)"
                )
            }
        }
    }
}


#endif
