import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
import TokfuelCore
import TokfuelSettings
#endif

@MainActor
public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private var didConfigure = false

    private init() {}

    public func start() {
        guard RemoteDiagnosticsPolicy.enablesCrashlytics else { return }
        configureFirebaseIfNeeded()
        applyAnalyticsConsent(AppSettings.shared.analyticsConsent)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let macOS = String(ProcessInfo.processInfo.operatingSystemVersionString.prefix(64))
        UsageEventLog.shared.log(.appLaunch, meta: [
            "app_version": version,
            "macos_version": macOS,
        ])
    }

    public func applyAnalyticsConsent(_ consent: Bool) {
        guard didConfigure else { return }
        let enabled = RemoteDiagnosticsPolicy.enablesAnalytics(consent: consent)
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    public func track(_ event: UsageEvent, meta: [String: String] = [:]) {
        guard RemoteDiagnosticsPolicy.enablesAnalytics(consent: AppSettings.shared.analyticsConsent)
        else { return }
        guard didConfigure else { return }
        guard let params = RemoteDiagnosticsPolicy.sanitizedParameters(
            event: event.rawValue, meta: meta)
        else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: params.isEmpty ? nil : params)
        #endif
    }


    private func configureFirebaseIfNeeded() {
        guard !didConfigure else { return }
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") == nil {
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        didConfigure = true
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        #endif
    }
}
