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
    private let usageStore = UsageStore()
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.syncLoginItem()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Tokfuel")
            button.image?.size = NSSize(width: 16, height: 16)
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(store: usageStore, onOpenSettings: { [weak self] in
                self?.openSettings()
            })
        )

        // 集計期間は UsageStore が「最後に選んだ値」を自分で復元する（CU-0011）。
        // 設定の既定値は初回（未選択）時のフォールバックと、明示的な変更時のみ反映する。

        // データ更新のたびにメニューバーの「今日の数字」を更新する。
        usageStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusTitle() }
            .store(in: &cancellables)

        // 設定変更を反映する。
        settings.$menuBarDisplay
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)
        settings.$defaultPeriodDays
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] days in self?.usageStore.reportDays = days }
            .store(in: &cancellables)
        settings.$language
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reloadReport() }
            .store(in: &cancellables)
        // スキャン場所が変わったら再走査する。
        Publishers.Merge(settings.$claudeDirectory.dropFirst().map { _ in () },
                         settings.$repositoryRoot.dropFirst().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.usageStore.reload() }
            .store(in: &cancellables)
        // 予算設定が変わったら再計算。上限を新たに設定したら通知許可も求める。
        Publishers.Merge3(settings.$budgetLimit.dropFirst().map { _ in () },
                          settings.$budgetPeriod.dropFirst().map { _ in () },
                          settings.$budgetWarnPercent.dropFirst().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                if AppSettings.shared.budgetLimit > 0 {
                    BudgetMonitor.requestAuthorizationIfNeeded()
                }
                self?.usageStore.reloadBudget()
            }
            .store(in: &cancellables)
        // サーバー真値クォータのオプトインが切り替わったら即反映する。
        settings.$serverQuotaEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.usageStore.reloadQuota() }
            .store(in: &cancellables)
        // 予算消費額が更新されたらアイコン色と通知を評価する。
        usageStore.$budgetSpend
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluateBudget() }
            .store(in: &cancellables)

        usageStore.reload()
        updateStatusTitle()

        // ポップオーバーを開かなくてもメニューバーの数字が古くならないよう定期更新する。
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.usageStore.reload() }
        }
    }

    /// 予算レベルに応じてアイコン色を変え、必要なら通知を送る。
    private func evaluateBudget() {
        updateStatusIcon()
        guard let level = usageStore.budgetLevel,
              let spend = usageStore.budgetSpend else { return }
        BudgetMonitor.notifyIfNeeded(
            level: level, spend: spend, limit: settings.budgetLimit,
            periodKey: BudgetMonitor.periodKey(for: settings.budgetPeriod))
    }

    /// メニューバーアイコン。通常はテンプレート（自動色）、警告でオレンジ、超過で赤。
    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let base = NSImage(systemSymbolName: "chart.bar.fill",
                           accessibilityDescription: "Tokfuel")
        let image: NSImage?
        switch usageStore.budgetLevel {
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
            if let cost = usageStore.todayCost {
                button.title = " " + PopoverView.money(cost)
                button.toolTip = "今日の推定コスト: \(String(format: "$%.2f", cost))"
            } else {
                let prompts = usageStore.today.prompts
                button.title = " \(prompts)"
                button.toolTip = "今日のプロンプト数: \(prompts)"
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            usageStore.reload()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            UsageEventLog.shared.log(.popoverOpen)
        }
    }

    /// 設定ウィンドウを開く。アクセサリアプリのため明示的に前面化する。
    private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
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
}
