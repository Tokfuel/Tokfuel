import SwiftUI
import Combine
import AppKit
import TokfuelCore
import TokfuelSettings
import TokfuelClaude
import TokfuelCursor
import TokfuelCodex
import TokfuelBudget
import TokfuelAnalytics
import TokfuelStore
import TokfuelUI

@main
struct TokfuelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var analyticsConsentWindow: NSWindow?
    private let usageStore: UsageStore
    private let settings: AppSettings
    private let updater = UpdateChecker.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var outsideClickMonitor: Any?
    /// 使用額が動いている間だけ更新間隔を上げる状態機械（TF-0080）。判定はここが持つ。
    private var scheduler = RefreshScheduler()
    private var isFollowing = false
    private var lastFullReload = Date.distantPast
    private var glowTimer: Timer?
    private var glowPhase: Double = 0

    override init() {
        AppSettings.bootstrap(codexInstalled: CodexCostDriver().isAvailable)
        let settings = AppSettings.shared
        UsageEventLog.analyticsTracker = { event, meta in
            Task { @MainActor in
                AnalyticsService.shared.track(event, meta: meta)
            }
        }
        settings.onAnalyticsConsentChange = { consent in
            AnalyticsService.shared.applyAnalyticsConsent(consent)
        }
        self.settings = settings
        self.usageStore = UsageStore(
            settings: settings,
            costDrivers: [CursorCostDriver(), CodexCostDriver()]
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // README 用スクリーンショットの生成（TF-0015）。常駐せずに書き出して終了する。
        if CommandLine.arguments.contains("--screenshot") {
            ScreenshotRenderer.runAndExit()
        }
        // PR の ui-preview 📸 ラベル用（TF-0034）。全画面をまとめて 1 ディレクトリに書き出す。
        if CommandLine.arguments.contains("--ui-preview") {
            ScreenshotRenderer.runAllAndExit()
        }
        if CommandLine.arguments.contains("--verify-cursor-ui") {
            VerifyCursorUI.runAndExit()
        }
        #endif

        NSApp.setActivationPolicy(.accessory)
        settings.syncLoginItem()
        applyAppearance()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        // 誤認してポップオーバーが閉じることがある。閉じる判定は自前で行う。
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(store: usageStore,
                                  settings: settings,
                                  updater: updater,
                                  onOpenSettings: { [weak self] in self?.openSettings() },
                                  onOpenAbout: { [weak self] in self?.openAbout() })
            .tint(.orange)   // 燃料ブランドのアクセント 1 色に統一
        )


        bindStateChanges()

        lastFullReload = Date()
        usageStore.reload()
        updateStatusItem()

        armRefreshTimer(interval: RefreshScheduler.baseInterval)
        observeSystemState()

        // は冒頭の runAndExit (-> Never) でここに到達しないので、撮影に混ざらない。
        updater.startPeriodicChecks()

        AnalyticsService.shared.start()
        promptAnalyticsConsentIfNeeded()

        #if DEBUG
        if CommandLine.arguments.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.togglePopover()
            }
        }
        #endif
    }

    /// 中身は `AnalyticsConsentView`（ui-preview と同じビュー）なので、文面を変えたら絵も追従する。
    private func promptAnalyticsConsentIfNeeded() {
        guard !settings.analyticsConsentAnswered else { return }
        guard analyticsConsentWindow == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let root = AnalyticsConsentView(
                onAllow: { [weak self] in self?.finishAnalyticsConsent(allow: true) },
                onDeny: { [weak self] in self?.finishAnalyticsConsent(allow: false) }
            )
            .tint(.orange)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = AnalyticsConsentView.title
            window.isReleasedWhenClosed = false
            window.center()
            self.analyticsConsentWindow = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func finishAnalyticsConsent(allow: Bool) {
        settings.analyticsConsent = allow
        analyticsConsentWindow?.orderOut(nil)
        analyticsConsentWindow = nil
    }

    private func bindStateChanges() {
        usageStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.observeActivity()
                self?.updateStatusItem()
                self?.notifyBudgetIfNeeded()
            }
            .store(in: &cancellables)

        Publishers.Merge(settings.$adaptiveRefreshEnabled.dropFirst().map { _ in () },
                         settings.$activityAnimationEnabled.dropFirst().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyRefreshDecision() }
            .store(in: &cancellables)

        settings.$appearanceMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyAppearance() }
            .store(in: &cancellables)

        Publishers.MergeMany(
            settings.$menuBarMetric.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$menuBarRepresentation.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$menuBarPercentBasis.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$menuBarGaugeShape.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$menuBarShowsIcon.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$menuBarShowsRemaining.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$costSourceMode.dropFirst().map { _ in () }.eraseToAnyPublisher())
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem()
                // ソース表示は todayCost / budgetSpend の合成に効くので、ストアも再描画させる。
                self?.usageStore.objectWillChange.send()
                self?.usageStore.reloadBudget()
            }
            .store(in: &cancellables)
        settings.$costModelBreakdownMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.objectWillChange.send() }
            .store(in: &cancellables)
        settings.$language
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reloadReport() }
            .store(in: &cancellables)
        settings.$weekStart
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reloadReport() }
            .store(in: &cancellables)
        settings.$claudeDirectory.dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reload() }
            .store(in: &cancellables)
        Publishers.Merge4(settings.$budgetLimit.dropFirst().map { _ in () },
                          settings.$dailyBudgetLimit.dropFirst().map { _ in () },
                          settings.$budgetPeriod.dropFirst().map { _ in () },
                          settings.$budgetWarnPercent.dropFirst().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                if settings.budgetLimit > 0 || settings.dailyBudgetLimit > 0 {
                    BudgetMonitor.requestAuthorizationIfNeeded()
                }
                usageStore.reloadBudget()
                // 集計値が動かないとストアは何も publish しないので、ここで自分で作り直す。
                updateStatusItem()
                notifyBudgetIfNeeded()
            }
            .store(in: &cancellables)
        settings.$displayCurrency
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await ExchangeRateService.refreshIfNeeded()
                    self?.usageStore.objectWillChange.send()   // 金額表示の再フォーマット
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)

        #if DEBUG
        // デバッグ上書きは実データを介さないので、ここで直接表示を作り直す。
        DebugSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem()
                self?.usageStore.objectWillChange.send()   // ポップオーバー・設定プレビュー
            }
            .store(in: &cancellables)
        #endif
    }

    private func notifyBudgetIfNeeded() {
        let style = settings.budgetAlertStyle
        let openSettings: () -> Void = { [weak self] in self?.openSettings() }
        if let level = usageStore.budgetLevel {
            if let content = BudgetMonitor.notifyIfNeeded(
                kind: .monthly, level: level, spend: usageStore.budgetSpend,
                limit: settings.budgetLimitUSD,
                periodKey: BudgetMonitor.periodKey(for: settings.budgetPeriod),
                style: style) {
                BudgetAlertWindow.shared.show(content, onOpenSettings: openSettings)
            }
        }
        if let level = usageStore.dailyBudgetLevel {
            if let content = BudgetMonitor.notifyIfNeeded(
                kind: .daily, level: level, spend: usageStore.todayCost,
                limit: settings.dailyBudgetLimitUSD,
                periodKey: BudgetMonitor.dailyPeriodKey(),
                style: style) {
                BudgetAlertWindow.shared.show(content, onOpenSettings: openSettings)
            }
        }
    }


    private func observeSystemState() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification,
                              object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAfterWake() }
        }
        workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                              object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateGlowAnimation() }
        }
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateGlowAnimation() }
        }
    }

    private func refreshTick() {
        let now = Date()
        // タイマーの起動誤差で 1 回飛ばさないよう、基準間隔の手前でも長期集計に切り替える。
        if now.timeIntervalSince(lastFullReload) >= RefreshScheduler.baseInterval - 5 {
            lastFullReload = now
            usageStore.reload()
        } else {
            usageStore.reloadToday()
        }
        applyRefreshDecision(now: now)
    }

    private func refreshAfterWake() {
        lastFullReload = Date()
        usageStore.reload()
        applyRefreshDecision()
    }

    private func observeActivity(now: Date = Date()) {
        let decision = scheduler.observe(costs: usageStore.todayCostBySource, now: now,
                                         enabled: settings.adaptiveRefreshEnabled)
        apply(decision)
    }

    private func applyRefreshDecision(now: Date = Date()) {
        apply(scheduler.resolve(now: now, enabled: settings.adaptiveRefreshEnabled))
    }

    private func apply(_ decision: RefreshScheduler.Decision) {
        isFollowing = decision.isFollowing
        if decision.intervalChanged { armRefreshTimer(interval: decision.interval) }
        updateGlowAnimation()
    }

    private func armRefreshTimer(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refreshTick() }
        }
    }

    private var animatesActivity: Bool {
        isFollowing
            && settings.adaptiveRefreshEnabled
            && settings.activityAnimationEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func updateGlowAnimation() {
        guard animatesActivity else {
            guard glowTimer != nil || glowPhase != 0 else { return }
            glowTimer?.invalidate()
            glowTimer = nil
            glowPhase = 0
            updateStatusItem()
            return
        }
        guard glowTimer == nil else { return }
        glowTimer = Timer.scheduledTimer(withTimeInterval: MenuBarImage.glowFrameInterval,
                                         repeats: true) { _ in
            Task { @MainActor [weak self] in self?.advanceGlow() }
        }
    }

    private func advanceGlow() {
        let step = MenuBarImage.glowFrameInterval / MenuBarImage.glowCycle
        glowPhase = (glowPhase + step).truncatingRemainder(dividingBy: 1)
        updateStatusItem()
    }


    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let content = MenuBarReadout.content(for: usageStore.menuBarInput(isFollowing: isFollowing))
        let animates = content.isFollowing && animatesActivity
        button.image = MenuBarImage.statusItem(for: content,
                                               glowPhase: animates ? glowPhase : nil)
        button.title = content.title.isEmpty ? "" : " " + content.title
        button.toolTip = content.toolTip
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            usageStore.reload()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            UsageEventLog.shared.log(.popoverOpen)
            // 他アプリをクリックしたら閉じる（自アプリ内のメニュー操作では発火しない）。
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in self?.closePopover() }
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func applyAppearance() {
        NSApp.appearance = settings.appearanceMode.nsAppearance
    }

    private func openSettings() {
        closePopover()
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(store: usageStore, settings: settings)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = MenuBarReadout.windowTitle("Tokfuel 設定")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UsageEventLog.shared.log(.settingsOpen)
    }

    private func openAbout() {
        closePopover()
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = MenuBarReadout.windowTitle("Tokfuel について")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppearanceMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
