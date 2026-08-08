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

/// Firebase Analytics / Crashlytics の唯一の送信面（#22）。
///
/// - 配布ビルド以外では `FirebaseApp.configure()` すら呼ばない（通信ゼロ）。
/// - Crashlytics は配布ビルドで常時 ON（同意なし）。
/// - Analytics は配布ビルドかつ `AppSettings.analyticsConsent` が ON のときだけ収集する。
/// - transcript / コスト / パスなど Claude 由来のデータは許可リスト外のため送れない。
@MainActor
public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private var didConfigure = false

    private init() {}

    /// 起動時に一度呼ぶ。配布ビルドで Firebase を立ち上げ、Analytics 収集の ON/OFF を同期する。
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

    /// Settings の同意トグル変更時。
    public func applyAnalyticsConsent(_ consent: Bool) {
        guard didConfigure else { return }
        let enabled = RemoteDiagnosticsPolicy.enablesAnalytics(consent: consent)
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    /// ローカル `UsageEvent` と同じ名前空間のイベントを、許可リスト経由で送る。
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

    // MARK: - Private

    private func configureFirebaseIfNeeded() {
        guard !didConfigure else { return }
        #if canImport(FirebaseCore)
        // GoogleService-Info.plist は package-app.sh が Contents/Resources に置く。
        // 無い・壊れているときは静かに諦める（開発用の不完全バンドルでも落とさない）。
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
