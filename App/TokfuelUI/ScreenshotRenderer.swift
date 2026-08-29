#if DEBUG
import AppKit
import SwiftUI
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor
import TokfuelCodex

/// 手描きモックではなく実 UI を撮るので、UI を変えれば絵も追従する。
@MainActor
public enum ScreenshotRenderer {
    public static let canvas = CGSize(width: 640, height: 584)
    public static let settleSeconds: TimeInterval = 0.6
    public static let reportPeriod: ReportPeriod = .thisWeek
    public static let reportDays = 7
    public static let dailyCosts: [Double] = [8.42, 15.10, 6.05, 21.30, 11.80, 24.90, 12.34]
    public static let modelCosts: [String: Double] = [
        "claude-fable-5": 68.30,
        "claude-sonnet-5": 20.16,
        "claude-haiku-4-5-20251001": 11.45
    ]
    public static let budgetLimit: Double = 300
    public static let budgetSpend: Double = 250
    public static let dailyBudgetLimit: Double = 20
    public static let cursorTodayCost: Double = 4.20
    public static let cursorModelCosts: [String: Double] = [
        "claude-4.5-sonnet": 3.36,
        "gpt-5-codex": 0.84,
        "composer-1": 0
    ]
    public static let popoverSize = CGSize(width: 360, height: 520)
    public static let previewUpdateVersion = "0.1.0"

    public enum RenderError: LocalizedError {
        case usage
        case renderFailed

        public var errorDescription: String? {
            switch self {
            case .usage: return "usage: Tokfuel --screenshot <output.png> | --ui-preview <output-dir>"
            case .renderFailed: return "画面のレンダリングに失敗しました"
            }
        }
    }


    public static func runAndExit(arguments: [String] = CommandLine.arguments) -> Never {
        do {
            guard let path = outputPath(arguments: arguments) else { throw RenderError.usage }
            prepareDefaults()
            let url = URL(fileURLWithPath: path)
            try renderPNG(store: fixtureStore()).write(to: url)
            print("wrote \(url.path)")
            exit(0)
        } catch {
            let message = error.localizedDescription + "\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    public nonisolated static func outputPath(arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--screenshot") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    public static func runAllAndExit(arguments: [String] = CommandLine.arguments) -> Never {
        do {
            guard let dirPath = outputDirectory(arguments: arguments) else { throw RenderError.usage }
            prepareDefaults()
            let dir = URL(fileURLWithPath: dirPath)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (name, data) in try allScreens() {
                let url = dir.appendingPathComponent("\(name).png")
                try data.write(to: url)
                print("wrote \(url.path)")
            }
            exit(0)
        } catch {
            let message = error.localizedDescription + "\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    public nonisolated static func outputDirectory(arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--ui-preview") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    /// 1 画面に入らない状態や折り畳み内の UI は、別名のスクリーンショットでしか写せない。
    public static func allScreens() throws -> [(name: String, data: Data)] {
        let store = fixtureStore()
        let settingsSize = CGSize(width: 460, height: 620)
        let aboutProbeSize = CGSize(width: 320, height: 800)
        // About / 予算アラートは幅だけ固定し、高さは fittingSize に任せる（probeSize が最終サイズになる）。
        let alertProbeSize = CGSize(width: 360, height: 400)
        let consentProbeSize = CGSize(width: 460, height: 400)
        return [
            ("popover", try renderPNG(store: store)),
            ("popover-light", try renderStandalone(
                PopoverView(store: store),
                probeSize: popoverSize, colorScheme: .light)),
            ("popover-update", try renderPNG(store: store,
                                             updater: .preview(version: previewUpdateVersion))),
            ("popover-cursor-degraded", try renderPNG(store: degradedCursorStore())),
            ("popover-cursor-signin", try renderPNG(
                store: degradedCursorStore(reason: .credentialsRejected))),
            ("popover-sessions", try renderStandalone(
                PopoverView(store: sessionsFixtureStore()),
                probeSize: popoverSize, scrollsToBottom: true)),
            ("popover-advice", try renderPNG(store: store, scrollsToBottom: true)),
            ("popover-advice-expanded", try renderStandalone(
                PopoverView(store: store, initiallyExpandsAdvice: true),
                probeSize: popoverSize, scrollsToBottom: true)),
            ("settings", try renderStandalone(SettingsView(store: store), probeSize: settingsSize)),
            ("settings-advanced", try renderStandalone(
                SettingsView(store: store, initiallyShowsAdvanced: true),
                probeSize: settingsSize, scrollsToBottom: true)),
            ("settings-debug", try renderStandalone(
                SettingsView(store: store, initiallyShowsAdvanced: true, initiallyShowsDebug: true),
                probeSize: settingsSize, scrollsToBottom: true)),
            ("about", try renderStandalone(AboutView(), probeSize: aboutProbeSize)),
            ("budget-alert", try renderStandalone(BudgetAlertView(content: budgetAlertContent),
                                                  probeSize: alertProbeSize)),
            ("analytics-consent", try renderStandalone(
                AnalyticsConsentView(), probeSize: consentProbeSize))
        ]
    }

    /// アップデート提示や折り畳み下のセクションは、引数や scrollsToBottom でないと絵に写らない。
    private static func renderPNG(store: UsageStore, updater: UpdateChecker = .shared,
                                  scrollsToBottom: Bool = false) throws -> Data {
        let view = NSHostingView(rootView: composition(store: store, updater: updater, now: Date()))
        view.frame = CGRect(origin: .zero, size: canvas)
        return try capture(view, size: canvas, scrollsToBottom: scrollsToBottom)
    }

    private static func renderStandalone<V: View>(
        _ rootView: V, probeSize: CGSize, scrollsToBottom: Bool = false,
        colorScheme: ColorScheme = .dark
    ) throws -> Data {
        let hosting = NSHostingView(rootView:
            rootView
                .environment(\.colorScheme, colorScheme)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(.orange)
                .background(Color(nsColor: .windowBackgroundColor)))
        // 先に画面外へ置いて 1 度レイアウトしないと fittingSize が (0, 0) のままになる。
        hosting.frame = CGRect(origin: .zero, size: probeSize)
        let probeWindow = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                                   backing: .buffered, defer: false)
        // chromeTint など NSAppearance 依存色はウィンドウ外観を見るので、絵の scheme と揃える。
        probeWindow.appearance = nsAppearance(for: colorScheme)
        probeWindow.contentView = hosting
        probeWindow.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        probeWindow.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width <= 0 { size.width = probeSize.width }
        if size.height <= 0 { size.height = probeSize.height }
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        // DisclosureGroup の中身は scrollsToBottom でないと写らない。
        if scrollsToBottom {
            RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
            scrollToBottom(in: hosting)
        }

        return try capture(hosting, size: size, colorScheme: colorScheme)
    }

    private static func scrollToBottom(in view: NSView) {
        guard let scrollView = firstScrollView(in: view) else { return }
        scrollView.layoutSubtreeIfNeeded()
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    /// NSAppearance 依存色は environment だけでは変わらないので、ウィンドウの appearance を揃える。
    private static func nsAppearance(for colorScheme: ColorScheme) -> NSAppearance? {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }

    private static func capture(_ view: NSHostingView<some View>, size: CGSize,
                                scrollsToBottom: Bool = false,
                                colorScheme: ColorScheme = .dark) throws -> Data {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = nsAppearance(for: colorScheme)
        window.backgroundColor = .clear
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        // SwiftUI の更新はランループ越しに走るので、描画が落ち着くまで回してから取り込む。
        RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
        if scrollsToBottom { scrollToBottom(in: view) }
        window.displayIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            throw RenderError.renderFailed
        }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.renderFailed
        }
        return png
    }

    /// インストール済み Tokfuel.app の UserDefaults には触らない（専用ドメインで上書きする）。
    private static func prepareDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UsageEventLog.enabledKey)
        defaults.set(false, forKey: "analyticsConsent")
        defaults.set(true, forKey: "analyticsConsentAnswered")
        defaults.set(DisplayCurrency.usd.rawValue, forKey: Money.currencyKey)
        // 変えると retok の再解析が走ってスピナーが写るため、初期化前にキーを直接書く。
        defaults.set(reportPeriod.rawValue, forKey: UsageStore.reportPeriodKey)
        defaults.set(CostChartStyle.daily.rawValue, forKey: UsageStore.costChartStyleKey)

        let settings = AppSettings.shared
        settings.budgetLimit = budgetLimit
        settings.dailyBudgetLimit = dailyBudgetLimit
        settings.budgetWarnPercent = 80
        settings.budgetPeriod = .calendarMonth
        settings.budgetAlertStyle = .notification
        settings.costSourceMode = .sideBySide
        settings.adaptiveRefreshEnabled = true
        settings.activityAnimationEnabled = true
        settings.appearanceMode = .dark
    }


    private static func composition(store: UsageStore, updater: UpdateChecker, now: Date) -> some View {
        VStack(spacing: 0) {
            menuBar(now: now)
            popoverCard(store: store, updater: updater)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8)
                .padding(.trailing, 24)
            Spacer(minLength: 0)
        }
        .frame(width: canvas.width, height: canvas.height)
        .background(desktop)
        .environment(\.colorScheme, .dark)
        // UI は日本語なので、CI（英語ロケール）でも同じ絵になるよう固定する。
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .tint(.orange)   // App.swift と同じアクセント
    }

    private static var desktop: some View {
        LinearGradient(colors: [Color(red: 0.18, green: 0.18, blue: 0.20),
                                Color(red: 0.11, green: 0.11, blue: 0.12)],
                       startPoint: .top, endPoint: .bottom)
    }

    private static func menuBar(now: Date) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.logo")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
            ForEach(["Finder", "File", "Edit", "View", "Window", "Help"], id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: item == "Finder" ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            HStack(spacing: 3) {
                Image(systemName: "fuelpump.fill")
                Text(PopoverView.money(dailyCosts.last ?? 0))
                    .monospacedDigit()
            }
            .foregroundStyle(.orange)
            Text(now, style: .time)
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.black.opacity(0.55))
    }

    private static func popoverCard(store: UsageStore, updater: UpdateChecker) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return PopoverView(store: store, updater: updater)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }


    public static func fixtureStore() -> UsageStore {
        let store = UsageStore(costDrivers: [CursorCostDriver(), CodexCostDriver()])
        store.report = fixtureReport()
        store.budgetSpend = budgetSpend
        store.driverDailyByID = ["cursor": [dateString(daysAgo: 0): cursorTodayCost]]
        store.driverModelByID = ["cursor": cursorModelCosts]
        store.lastUpdated = Date()
        return store
    }

    public static func degradedCursorStore() -> UsageStore {
        degradedCursorStore(reason: .remoteUnavailable)
    }

    public static func degradedCursorStore(reason: CostSnapshot.Degradation) -> UsageStore {
        let store = fixtureStore()
        store.driverDailyByID = ["cursor": [:]]
        store.driverHealthByID = ["cursor": .degraded(reason)]
        return store
    }

    /// `budgetSpend` / `budgetLimit` から作るので、ポップオーバーの予算ゲージと数字が揃う。
    public static var budgetAlertContent: BudgetAlertContent {
        BudgetAlertContent(
            kind: .monthly, level: .warning, spend: budgetSpend, limit: budgetLimit,
            message: BudgetMonitor.message(kind: .monthly, level: .warning,
                                           spend: budgetSpend, limit: budgetLimit)!)
    }

    /// README の 1 枚目に入らないセッション一覧は、専用画面で末尾までスクロールして撮る。
    public static func sessionsFixtureStore() -> UsageStore {
        let store = fixtureStore()
        store.report = fixtureReport(topSessions: claudeTopSessions, advice: [])
        store.driverSessionsByID = ["cursor": cursorSessions]
        return store
    }

    public static let claudeTopSessions: [RetokReport.TopSession] = [
        RetokReport.TopSession(session: "8f2c1a4b", project: "tokfuel/menu-bar-gauge",
                               cost: 18.42, prompts: 64, maxContext: 168_000),
        RetokReport.TopSession(session: "3b90de17", project: "tokfuel/cost-popover",
                               cost: 7.05, prompts: 22, maxContext: 92_000)
    ]

    public static var cursorSessions: [CostSnapshot.Session] {
        [
            CostSnapshot.Session(id: "0041d255", title: "SwiftUI のレイアウト崩れを直す",
                                 cost: 11.20, messages: 38, lastUsed: dateString(daysAgo: 0)),
            CostSnapshot.Session(id: "9c7ee301", title: CursorUsageReader.untitledSessionTitle,
                                 cost: 2.60, messages: 9, lastUsed: dateString(daysAgo: 2))
        ]
    }

    /// Claude 由来（retok）と Cursor 由来のヒントが並んだ状態——ソースバッジと severity 順——を写す。
    public static let fixtureAdvice: [RetokReport.Advice] = [
        RetokReport.Advice(
            severity: "medium",
            key: "adv_model_mix",
            title: "高価格モデルでの小粒セッションが 12 件 ($18.40)",
            detail: "一問一答や軽い確認は Haiku/Sonnet で十分なことが多いです。"
                + "/model で切り替えるか、軽い用途向けに別プロファイルを用意すると"
                + "節約できます。")
    ]

    public static func fixtureReport(
        topSessions: [RetokReport.TopSession] = [],
        advice: [RetokReport.Advice] = fixtureAdvice
    ) -> RetokReport {
        var daily: [String: RetokReport.DailyCost] = [:]
        for (offset, cost) in dailyCosts.reversed().enumerated() {
            daily[dateString(daysAgo: offset)] = RetokReport.DailyCost(cost: cost,
                                                                      output: Int(cost * 780))
        }
        let total = dailyCosts.reduce(0, +)
        return RetokReport(
            periodDays: reportDays,
            filesScanned: 214,
            totals: RetokReport.Totals(cost: total, input: 1_284_000, output: 96_400,
                                       cacheRead: 18_900_000, cacheWrite: 2_150_000,
                                       prompts: 356, requests: 812),
            cacheHitRate: 0.86,
            perModel: modelCosts.mapValues { cost -> RetokReport.ModelUsage in
                // 絵に出るのはコストだけなので、トークン数はコストから機械的に置く。
                RetokReport.ModelUsage(cost: cost, input: Int(cost * 10_800),
                                       output: Int(cost * 890), requests: Int(cost * 6))
            },
            daily: daily,
            advice: advice,
            topSessions: topSessions
        )
    }

    public static func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return UsageStore.dateString(date)
    }
}
#endif
