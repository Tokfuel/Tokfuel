import SwiftUI
import Combine
import AppKit

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
    /// 初回 Analytics 同意ダイアログ。答えるまで保持する。
    private var analyticsConsentWindow: NSWindow?
    private let usageStore = UsageStore()
    private let settings = AppSettings.shared
    private let updater = UpdateChecker.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    /// ポップオーバー表示中の「外側クリックで閉じる」監視。
    private var outsideClickMonitor: Any?
    /// 使用額が動いている間だけ更新間隔を上げる状態機械（TF-0080）。判定はここが持つ。
    private var scheduler = RefreshScheduler()
    /// 追従モード中か。メニューバーの明滅の可否に効く。
    private var isFollowing = false
    /// 長期集計（32 日）を最後に回した時刻。追従中でもここは基準間隔のまま保つ。
    private var lastFullReload = Date.distantPast
    /// 明滅アニメーションのタイマーと位相（0…1）。
    private var glowTimer: Timer?
    private var glowPhase: Double = 0

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
        // Cursor 二次ソースの実スキャン → ポップオーバー描画検証。常駐せずに終了する。
        if CommandLine.arguments.contains("--verify-cursor-ui") {
            VerifyCursorUI.runAndExit()
        }
        #endif

        NSApp.setActivationPolicy(.accessory)
        settings.syncLoginItem()
        applyAppearance()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 画像とタイトルは updateStatusItem が設定する（表現によって給油機とリングが入れ替わる）。
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        // .transient だと ⋯ メニューを開いた瞬間にフォーカス移動を「外側クリック」と
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

        // 集計期間は UsageStore が「最後に選んだ値」を自分で復元する（CU-0011）。
        // 設定の既定値は初回（未選択）時のフォールバックと、明示的な変更時のみ反映する。

        bindStateChanges()

        lastFullReload = Date()
        usageStore.reload()
        updateStatusItem()

        // ポップオーバーを開かなくてもメニューバーの数字が古くならないよう定期更新する。
        // 間隔は RefreshScheduler が決める（平常は 10 分、使用額が動いている間だけ 1 分）。
        armRefreshTimer(interval: RefreshScheduler.baseInterval)
        observeSystemState()

        // 新バージョンの確認（起動時 + 24 時間ごと）。ヘッドレス実行（スクリーンショット等）
        // は冒頭の runAndExit (-> Never) でここに到達しないので、撮影に混ざらない。
        updater.startPeriodicChecks()

        // Firebase（#22）。配布ビルド以外では no-op。Analytics は同意後のみ。
        AnalyticsService.shared.start()
        promptAnalyticsConsentIfNeeded()

        #if DEBUG
        // 手動確認用: `Tokfuel --open-popover` で起動すると集計を待ってからポップオーバーを開く。
        if CommandLine.arguments.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.togglePopover()
            }
        }
        #endif
    }

    /// まだ Analytics 同意に答えていなければ初回ダイアログを出す。
    /// 送信そのものは配布ビルド側のゲート（`RemoteDiagnosticsPolicy`）に従う。
    /// Crashlytics は同意なしのためここでは扱わない。
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
            // accessory でもダイアログを前面に出す。
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func finishAnalyticsConsent(allow: Bool) {
        settings.analyticsConsent = allow
        analyticsConsentWindow?.orderOut(nil)
        analyticsConsentWindow = nil
    }

    /// ストアと設定の変更を、メニューバー、通知、再集計へ接続する。
    private func bindStateChanges() {
        usageStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                // 金額が動いたかの判定は、集計が届いたこのタイミングでしかできない。
                self?.observeActivity()
                self?.updateStatusItem()
                self?.notifyBudgetIfNeeded()
            }
            .store(in: &cancellables)

        // 追従モードと明滅のトグル。オフにしたら間隔とアニメーションを即座に戻す。
        Publishers.Merge(settings.$adaptiveRefreshEnabled.dropFirst().map { _ in () },
                         settings.$activityAnimationEnabled.dropFirst().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyRefreshDecision() }
            .store(in: &cancellables)

        // 外観は起動時に一度当て、あとは設定変更で即時反映する（再起動は不要）。
        settings.$appearanceMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyAppearance() }
            .store(in: &cancellables)

        // 設定変更を反映する。月表示や日次平均基準に切り替えたら 32 日集計も必要になる。
        // dropFirst が無いと購読時に 4 本ぶん発火し、起動直後に 32 日集計（python3 の
        // サブプロセス）が余分に走る。初回は下の reload() + updateStatusItem() が担う。
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
        // 「今週」の起点が変わったら表示窓を作り直す（他期間では結果は同じだが、再読込は安い）。
        settings.$weekStart
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reloadReport() }
            .store(in: &cancellables)
        // スキャン場所が変わったら再走査する。
        settings.$claudeDirectory.dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reload() }
            .store(in: &cancellables)
        // 予算設定が変わったら再計算。上限を新たに設定したら通知許可も求める。
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
                // 上限やしきい値を変えると、消費額が同じままでもアイコン色・残額・割合は変わる。
                // 集計値が動かないとストアは何も publish しないので、ここで自分で作り直す。
                updateStatusItem()
                notifyBudgetIfNeeded()
            }
            .store(in: &cancellables)
        // 表示通貨が変わったらレートを（必要なら）取得して表示を作り直す。
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

    /// 予算しきい値を越えたら通知する（月間・日次それぞれ。重複抑止は BudgetMonitor 側）。
    private func notifyBudgetIfNeeded() {
        // 知らせ方（通知 / アラートウィンドウ）は設定から読んで引数で渡す。
        let style = settings.budgetAlertStyle
        let openSettings: () -> Void = { [weak self] in self?.openSettings() }
        if let level = usageStore.budgetLevel {
            BudgetMonitor.notifyIfNeeded(
                kind: .monthly, level: level, spend: usageStore.budgetSpend,
                limit: settings.budgetLimit,
                periodKey: BudgetMonitor.periodKey(for: settings.budgetPeriod),
                style: style, onOpenSettings: openSettings)
        }
        if let level = usageStore.dailyBudgetLevel {
            BudgetMonitor.notifyIfNeeded(
                kind: .daily, level: level, spend: usageStore.todayCost,
                limit: settings.dailyBudgetLimit,
                periodKey: BudgetMonitor.dailyPeriodKey(),
                style: style, onOpenSettings: openSettings)
        }
    }

    // MARK: - 追従モード（TF-0080）

    /// スリープ復帰・低電力モード・視差効果の設定変更を拾う。
    /// 復帰時だけは経過時間にかかわらず 1 回即時更新し、そこで動きがあれば追従モードに入る。
    private func observeSystemState() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification,
                              object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAfterWake() }
        }
        // 明滅を止める条件（低電力モード / 視差効果を減らす）は、その場で切り替わる。
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

    /// 定期更新の 1 回ぶん。追従中の合間は「今日」の窓だけを取り直し、長期集計（32 日）は
    /// 基準間隔のまま回す（1 分ごとに 32 日走査をやり直さない）。
    private func refreshTick() {
        let now = Date()
        // タイマーの起動誤差で 1 回飛ばさないよう、基準間隔の手前でも長期集計に切り替える。
        if now.timeIntervalSince(lastFullReload) >= RefreshScheduler.baseInterval - 5 {
            lastFullReload = now
            usageStore.reload()
        } else {
            usageStore.reloadToday()
        }
        // 無風のまま 5 分が過ぎていれば、ここで基準間隔へ戻る。
        applyRefreshDecision(now: now)
    }

    /// スリープ復帰時の 1 回だけの即時更新。
    private func refreshAfterWake() {
        lastFullReload = Date()
        usageStore.reload()
        applyRefreshDecision()
    }

    /// 届いた集計値を状態機械に渡し、間隔とアニメーションをそろえる。
    private func observeActivity(now: Date = Date()) {
        let decision = scheduler.observe(costs: usageStore.todayCostBySource, now: now,
                                         enabled: settings.adaptiveRefreshEnabled)
        apply(decision)
    }

    /// 金額を観測せず、経過時間と設定だけで間隔を見直す。
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

    /// アイコンを明滅させてよいか。省電力とアクセシビリティの設定が優先で、
    /// どちらの場合も金額の更新間隔（追従モードそのもの）は変えない。
    private var animatesActivity: Bool {
        isFollowing
            && settings.adaptiveRefreshEnabled
            && settings.activityAnimationEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 明滅タイマーを条件に合わせて張り替える。止めるときは通常の画像へ戻す。
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

    /// 明滅の 1 コマぶん位相を進めて描き直す。
    private func advanceGlow() {
        let step = MenuBarImage.glowFrameInterval / MenuBarImage.glowCycle
        glowPhase = (glowPhase + step).truncatingRemainder(dividingBy: 1)
        updateStatusItem()
    }

    // MARK: - メニューバーの表示

    /// メニューバーの画像・タイトル・ツールチップを設定に従って作り直す。
    /// 何を出すかの判断は MenuBarReadout（設定プレビューと共用の純粋な計算）が持つ。
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let content = MenuBarReadout.content(for: usageStore.menuBarInput(isFollowing: isFollowing))
        let animates = content.isFollowing && animatesActivity
        button.image = MenuBarImage.statusItem(for: content,
                                               glowPhase: animates ? glowPhase : nil)
        // アイコンと数字がくっつくので 1 文字ぶん空ける。
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

    /// 保存済みの外観を `NSApp` に当てる。`system` は `nil`（OS 追従）に戻す。
    private func applyAppearance() {
        NSApp.appearance = settings.appearanceMode.nsAppearance
    }

    /// 設定ウィンドウを開く。アクセサリアプリのため明示的に前面化する。
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

    /// 「Tokfuel について」ウィンドウ（バージョン・作者・謝辞）を開く。
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
    /// `NSApp.appearance` に渡す値。`system` は OS 追従のため `nil`。
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
