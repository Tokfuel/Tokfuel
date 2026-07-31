import Testing
@testable import Tokfuel

@Suite("RemoteDiagnosticsPolicy")
struct RemoteDiagnosticsPolicyTests {
    @Test("Analytics は同意なしでは無効")
    func analyticsRequiresConsent() {
        #expect(RemoteDiagnosticsPolicy.enablesAnalytics(consent: false) == false)
    }

    @Test("許可リスト外のイベントは落とす")
    func rejectsUnknownEvents() {
        #expect(RemoteDiagnosticsPolicy.sanitizedParameters(
            event: "cost_viewed", meta: ["tab": "cost"]) == nil)
    }

    @Test("meta は許可キーだけ残す")
    func filtersMetaKeys() {
        let params = RemoteDiagnosticsPolicy.sanitizedParameters(
            event: "tab_open",
            meta: [
                "tab": "cost",
                "path": "/Users/secret/project",
                "amount": "12.3",
            ])
        #expect(params == ["tab": "cost"])
    }

    @Test("パスっぽい値は落とす")
    func rejectsPathLikeValues() {
        let params = RemoteDiagnosticsPolicy.sanitizedParameters(
            event: "setting_change",
            meta: ["key": "claudeDirectory", "tab": "a/b"])
        #expect(params == ["key": "claudeDirectory"])
    }

    @Test("配布フラグの有無で Crashlytics ゲートが決まる")
    func crashlyticsFollowsDistributionFlag() {
        #if DEBUG
        #expect(RemoteDiagnosticsPolicy.enablesCrashlytics == false)
        #expect(RemoteDiagnosticsPolicy.isDistributionBuild == false)
        #elseif TOKFUEL_DISTRIBUTION
        #expect(RemoteDiagnosticsPolicy.enablesCrashlytics == true)
        #expect(RemoteDiagnosticsPolicy.enablesAnalytics(consent: true) == true)
        #else
        #expect(RemoteDiagnosticsPolicy.enablesCrashlytics == false)
        #expect(RemoteDiagnosticsPolicy.enablesAnalytics(consent: true) == false)
        #endif
    }
}
