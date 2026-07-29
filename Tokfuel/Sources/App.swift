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
        #endif

        NSApp.setActivationPolicy(.accessory)
        settings.syncLoginItem()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "fuelpump.fill", accessibilityDescription: "Tokfuel")
            button.image?.size = NSSize(width: 16, height: 16)
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
                self?.updateStatusTitle()
                self?.evaluateBudget()
            }
            .store(in: &cancellables)

        // 設定変更を反映する。月表示に切り替えたら消費額の算出も必要になる。
        Publishers.Merge(settings.$menuBarDisplay.map { _ in () },
                         settings.$menuBarShowsRemaining.map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusTitle()
                self?.usageStore.reloadBudget()
            }
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
            }
            .store(in: &cancellables)
        // 表示通貨が変わったらレートを（必要なら）取得して表示を作り直す。
        settings.$displayCurrency
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await ExchangeRateService.refreshIfNeeded()
                    self?.usageStore.objectWillChange.send()   // 金額表示の再フォーマット
                    self?.updateStatusTitle()
                }
            }
            .store(in: &cancellables)

        #if DEBUG
        // デバッグ上書きは実データを介さないので、ここで直接表示を作り直す。
        DebugSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusTitle()
                self?.usageStore.objectWillChange.send()   // ポップオーバー・設定プレビュー
            }
            .store(in: &cancellables)
        #endif

        usageStore.reload()
        updateStatusTitle()

        // ポップオーバーを開かなくてもメニューバーの数字が古くならないよう定期更新する。
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.usageStore.reload() }
        }
    }

    /// 予算レベルに応じてアイコン色を変え、必要なら通知を送る（月間・日次それぞれ）。
    private func evaluateBudget() {
        updateStatusIcon()
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

    /// メニューバーアイコン。通常はテンプレート（自動色）、警告でオレンジ、超過で赤。
    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let base = NSImage(systemSymbolName: "fuelpump.fill",
                           accessibilityDescription: "Tokfuel")
        let image: NSImage?
        switch usageStore.combinedBudgetLevel {
        case .warning:
            image = base?.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
            image?.isTemplate = false
        case .over:
            image = base?.withSymbolConfiguration(.init(paletteColors: [.systemRed]))
            image?.isTemplate = false
        default:
            image = base   // テンプレート描画（メニューバーの明暗に追従）
        }
        image?.size = NSSize(width: 16, height: 16)
        button.image = image
    }

    /// 今日ぶんの表示値。残額モードかつ日次予算があれば「上限 − 消費」、なければ消費額。
    private func todayFigure() -> (text: String, tip: String) {
        let cost = usageStore.todayCost
        if settings.menuBarShowsRemaining, settings.dailyBudgetLimit > 0 {
            let remaining = settings.dailyBudgetLimit - cost
            return ("残 " + PopoverView.money(remaining),
                    "今日の残り予算: \(PopoverView.money(remaining))")
        }
        return (PopoverView.money(cost), "今日の推定コスト: \(PopoverView.money(cost))")
    }

    /// 今月ぶんの表示値。残額モードかつ月間予算があれば「上限 − 消費」、なければ消費額。
    private func monthFigure() -> (text: String, tip: String) {
        let spend = usageStore.budgetSpend
        if settings.menuBarShowsRemaining, settings.budgetLimit > 0 {
            let remaining = settings.budgetLimit - spend
            return ("残 " + PopoverView.money(remaining),
                    "今月の残り予算: \(PopoverView.money(remaining))")
        }
        return (PopoverView.money(spend), "今月の推定コスト: \(PopoverView.money(spend))")
    }

    /// メニューバー表示は設定に従う（コスト / プロンプト数 / アイコンのみ）。
    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        updateStatusIcon()
        switch settings.menuBarDisplay {
        case .iconOnly:
            button.title = ""
            button.toolTip = "Tokfuel"
        case .prompts:
            let prompts = usageStore.today.prompts
            button.title = " \(prompts)"
            button.toolTip = "今日のプロンプト数: \(prompts)"
        case .cost:
            let today = todayFigure()
            button.title = " " + today.text
            button.toolTip = today.tip
        case .monthlyCost:
            let month = monthFigure()
            button.title = " " + month.text
            button.toolTip = month.tip
        case .bothCosts:
            let (today, month) = (todayFigure(), monthFigure())
            button.title = " \(today.text) · 月 \(month.text)"
            button.toolTip = "\(today.tip) / \(month.tip)"
        }
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
            window.title = "Tokfuel 設定"
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
            window.title = "Tokfuel について"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
