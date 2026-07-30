import SwiftUI
import Combine

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
    private let usageStore = UsageStore()
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    /// ポップオーバー表示中の「外側クリックで閉じる」監視。
    private var outsideClickMonitor: Any?

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
                                  onOpenSettings: { [weak self] in self?.openSettings() },
                                  onOpenAbout: { [weak self] in self?.openAbout() })
            .tint(.orange)   // 燃料ブランドのアクセント 1 色に統一
        )

        // 集計期間は UsageStore が「最後に選んだ値」を自分で復元する（CU-0011）。
        // 設定の既定値は初回（未選択）時のフォールバックと、明示的な変更時のみ反映する。

        // データ更新のたびにメニューバーの表示と予算通知を更新する（通知は内部で重複抑止）。
        usageStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem()
                self?.notifyBudgetIfNeeded()
            }
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
                let s = AppSettings.shared
                if s.budgetLimit > 0 || s.dailyBudgetLimit > 0 {
                    BudgetMonitor.requestAuthorizationIfNeeded()
                }
                self?.usageStore.reloadBudget()
                // 上限やしきい値を変えると、消費額が同じままでもアイコン色・残額・割合は変わる。
                // 集計値が動かないとストアは何も publish しないので、ここで自分で作り直す。
                self?.updateStatusItem()
                self?.notifyBudgetIfNeeded()
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

        usageStore.reload()
        updateStatusItem()

        // ポップオーバーを開かなくてもメニューバーの数字が古くならないよう定期更新する。
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.usageStore.reload() }
        }

        #if DEBUG
        // 手動確認用: `Tokfuel --open-popover` で起動すると集計を待ってからポップオーバーを開く。
        if CommandLine.arguments.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.togglePopover()
            }
        }
        #endif
    }

    /// 予算しきい値を越えたら通知する（月間・日次それぞれ。重複抑止は BudgetMonitor 側）。
    private func notifyBudgetIfNeeded() {
        if let level = usageStore.budgetLevel {
            BudgetMonitor.notifyIfNeeded(
                kind: .monthly, level: level, spend: usageStore.budgetSpend,
                limit: settings.budgetLimit,
                periodKey: BudgetMonitor.periodKey(for: settings.budgetPeriod))
        }
        if let level = usageStore.dailyBudgetLevel {
            BudgetMonitor.notifyIfNeeded(
                kind: .daily, level: level, spend: usageStore.todayCost,
                limit: settings.dailyBudgetLimit,
                periodKey: BudgetMonitor.dailyPeriodKey())
        }
    }

    // MARK: - メニューバーの表示

    /// メニューバーの画像・タイトル・ツールチップを設定に従って作り直す。
    /// 何を出すかの判断は MenuBarReadout（設定プレビューと共用の純粋な計算）が持つ。
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let content = MenuBarReadout.content(for: usageStore.menuBarInput())
        button.image = MenuBarImage.statusItem(for: content)
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

    /// 設定ウィンドウを開く。アクセサリアプリのため明示的に前面化する。
    private func openSettings() {
        closePopover()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: usageStore))
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
