#if DEBUG
import Foundation

/// AX E2E（`--e2e-fixture`）用の起動準備。実ユーザーの Application Support は触らず、
/// `ScreenshotRenderer` と同じフィクスチャを常駐メニューバーに載せる。
@MainActor
enum E2EFixture {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--e2e-fixture")
    }

    /// UserDefaults / AppSettings をフィクスチャ既定にし、ネットワーク集計を止める準備をする。
    static func prepareLaunch() {
        ScreenshotRenderer.applyE2ELaunchDefaults()
    }

    /// ライブな `UsageStore` にフィクスチャを流し込み、以降の reload を no-op にする。
    static func seed(_ store: UsageStore) {
        ScreenshotRenderer.seedE2EStore(store)
        store.freezeNetworkIO = true
    }
}
#endif
