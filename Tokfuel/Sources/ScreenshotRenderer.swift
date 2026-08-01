#if DEBUG
import AppKit
import SwiftUI

/// README / Site に貼るスクリーンショットを、実物の `PopoverView` から生成する
/// （TF-0015 / #62）。手描きのモックアップと違い、UI を変えれば絵も追従する。
/// 既定では `scripts/screenshot.sh` が同じ PNG を README と Site の両方へ配る。
///
/// `Tokfuel --screenshot <出力先>` で起動すると、常駐処理に入る前にここで PNG を書き出して
/// 終了する。DEBUG ビルド専用なので配布バイナリには含まれない。
///
/// 実データ（`~/.claude/projects`）は読まず、下のフィクスチャだけを描く。retok も走らせない
/// （解析中のスピナーが写り込まないよう、期間は `UsageStore` の初期化前に決める）。
///
/// グラフやメーターの `Color.accentColor` は生成機のシステムアクセントカラーに従い、AppKit は
/// それを起動時に読む。どの機械でも同じ絵にするため `scripts/screenshot.sh` が
/// `-AppleAccentColor 1`（オレンジ）を起動引数で渡している。
@MainActor
enum ScreenshotRenderer {
    /// 画像の論理サイズ (pt)。@2x で書き出すので PNG は 2 倍のピクセル数になる。
    static let canvas = CGSize(width: 640, height: 584)
    /// 描画が落ち着くまでランループを回す時間（秒）。
    static let settleSeconds: TimeInterval = 0.6
    /// フィクスチャの集計期間。期間ピッカーの選択位置にもそのまま出る。
    static let reportPeriod: ReportPeriod = .thisWeek
    /// フィクスチャの日数（「今週」絵用の 7 本。実行曜日には依存させない）。
    static let reportDays = 7
    /// 日ごとのコスト (USD)。末尾が「今日」。ヒーローの金額はこの最後の値になる。
    static let dailyCosts: [Double] = [8.42, 15.10, 6.05, 21.30, 11.80, 24.90, 12.34]
    /// モデル別の内訳 (USD)。合計は `dailyCosts` の合計に一致させる（テストで検査）。
    static let modelCosts: [String: Double] = [
        "claude-fable-5": 68.30,
        "claude-sonnet-5": 20.16,
        "claude-haiku-4-5-20251001": 11.45
    ]
    /// 月間予算とその消費額。警告しきい値 80% を超える組にして、警告表示まで絵に入れる。
    static let budgetLimit: Double = 300
    static let budgetSpend: Double = 250
    /// 日次予算。今日のコストに対して余裕のある上限にする。
    static let dailyBudgetLimit: Double = 20
    /// Cursor（二次ソース）の今日のコスト。並べて表示モードで Claude と並ぶ絵になる。
    static let cursorTodayCost: Double = 4.20
<<<<<<< HEAD
    /// Cursor のモデル別内訳 (USD)。合計は `cursorTodayCost` に一致させる（テストで検査）。
    /// `composer-1` を $0 にして、価格表に無いモデル（`CursorPricing` が値付けできない）の
    /// ヒントまで絵に入れる。値付けできたぶんは 1 モデルに寄せ、偏りのヒントも出す。
    static let cursorModelCosts: [String: Double] = [
        "claude-4.5-sonnet": 3.36,
        "gpt-5-codex": 0.84,
        "composer-1": 0
    ]
=======
    /// ポップオーバー本体のサイズ（PopoverView 自身の `.frame` と同じ）。
    static let popoverSize = CGSize(width: 360, height: 520)
>>>>>>> origin/main
    /// フッターのアップデートボタンの絵に出す、フィクスチャの「提示中のバージョン」。
    static let previewUpdateVersion = "0.1.0"

    enum RenderError: LocalizedError {
        case usage
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .usage: return "usage: Tokfuel --screenshot <output.png> | --ui-preview <output-dir>"
            case .renderFailed: return "画面のレンダリングに失敗しました"
            }
        }
    }

    // MARK: - エントリポイント

    /// `--screenshot` 付きで起動されたときの入口。PNG を書き出してプロセスを終える。
    static func runAndExit(arguments: [String] = CommandLine.arguments) -> Never {
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

    /// `--screenshot <path>` の出力先。フラグが無い／パスが続かない場合は nil。
    nonisolated static func outputPath(arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--screenshot") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    /// `--ui-preview <dir>` 付きで起動されたときの入口（TF-0034）。PR の ui-preview 📸 ラベル用に、
    /// メニューバー・設定・About の全画面（折りたたみセクションを開いた状態も含む）を
    /// 1 ディレクトリへ書き出してプロセスを終える。
    static func runAllAndExit(arguments: [String] = CommandLine.arguments) -> Never {
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

    /// `--ui-preview <dir>` の出力先。フラグが無い／パスが続かない場合は nil。
    nonisolated static func outputDirectory(arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--ui-preview") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    /// 撮影する全画面。ファイル名（拡張子なし）→ PNG データ。
    /// - `popover`: メニューバー帯付きの合成（README と同じ絵）
    /// - `popover-update`: 同じ合成に、フッターがアップデートボタンを提示中の状態を重ねたもの
    /// - `popover-cursor-degraded`: Cursor の使用量 API に届かず、$0 の意味を注意書きで
    ///   断っている状態
    /// - `popover-cursor-signin`: 同じ注意書きに、サインインし直すボタンが付いた状態
<<<<<<< HEAD
    /// - `popover-advice`: 同じ合成を末尾までスクロールした状態（「節約のヒント」は
    ///   最初の 1 画面に入らないため、ここでしか見えない）
=======
    /// - `popover-sessions`: ポップオーバー単体を末尾までスクロールした状態
    ///   （折り返しの下にある「高コストのセッション」を Claude + Cursor で写す）
>>>>>>> origin/main
    /// - `settings` / `settings-advanced` / `settings-debug`: 設定ウィンドウ（既定・詳細を開いた状態・
    ///   デバッグを開いた状態）
    /// - `about`: 「Tokfuel について」ウィンドウ
    static func allScreens() throws -> [(name: String, data: Data)] {
        let store = fixtureStore()
        // 設定は自身が .frame(width: 460, height: 620) を持つ（SettingsView.swift）ので
        // probeSize がそのまま最終サイズになる。About は幅 320 だけを持つので、
        // 高さは余裕を持った probeSize から実際の fittingSize へ縮める。
        let settingsSize = CGSize(width: 460, height: 620)
        let aboutProbeSize = CGSize(width: 320, height: 800)
        return [
            ("popover", try renderPNG(store: store)),
            ("popover-update", try renderPNG(store: store,
                                             updater: .preview(version: previewUpdateVersion))),
            ("popover-cursor-degraded", try renderPNG(store: degradedCursorStore())),
            ("popover-cursor-signin", try renderPNG(
                store: degradedCursorStore(reason: .credentialsRejected))),
<<<<<<< HEAD
            ("popover-advice", try renderPNG(store: store, scrollsToBottom: true)),
=======
            ("popover-sessions", try renderStandalone(
                PopoverView(store: sessionsFixtureStore()),
                probeSize: popoverSize, scrollsToBottom: true)),
>>>>>>> origin/main
            ("settings", try renderStandalone(SettingsView(store: store), probeSize: settingsSize)),
            ("settings-advanced", try renderStandalone(
                SettingsView(store: store, initiallyShowsAdvanced: true),
                probeSize: settingsSize, scrollsToBottom: true)),
            ("settings-debug", try renderStandalone(
                SettingsView(store: store, initiallyShowsAdvanced: true, initiallyShowsDebug: true),
                probeSize: settingsSize, scrollsToBottom: true)),
            ("about", try renderStandalone(AboutView(), probeSize: aboutProbeSize))
        ]
    }

    /// フィクスチャを積んだポップオーバーを @2x で PNG にする。`updater` の既定は `.shared`
    /// （`available` は nil のまま）なので、ボタンを出したい画面だけ `.preview(version:)` を渡す。
    ///
    /// `ImageRenderer` ではなく `NSHostingView` を実際に描画させる。`ImageRenderer` は
    /// `ScrollView` の中身と AppKit 実装のコントロール（フッターの `Menu`・期間ピッカー）を
    /// 描けず、本文が空の絵になるため。
    ///
    /// `scrollsToBottom` はポップオーバーの `ScrollView` を末尾まで送ってから撮る。
    /// 折り返しの下にあるセクション（節約のヒント）は、そうしないと絵に写らない。
    private static func renderPNG(store: UsageStore, updater: UpdateChecker = .shared,
                                  scrollsToBottom: Bool = false) throws -> Data {
        let view = NSHostingView(rootView: composition(store: store, updater: updater, now: Date()))
        view.frame = CGRect(origin: .zero, size: canvas)
        return try capture(view, size: canvas, scrollsToBottom: scrollsToBottom)
    }

    /// 設定・About など、デスクトップ風の飾りを持たない単独ウィンドウを @2x で PNG にする。
    /// 本物のウィンドウ（`NSWindow(contentViewController:)`）と同じく、通常のウィンドウ背景色を
    /// 敷く（ポップオーバーの合成と違い透明にしない）。`probeSize` は最初のレイアウト用の仮サイズ
    /// で、`.frame` で高さを明示していないビュー（`AboutView`）向けに、実描画後の `fittingSize`
    /// で実寸へ縮める。幅・高さとも `.frame` で固定しているビュー（`SettingsView`）では
    /// `probeSize` がそのまま最終サイズになる。
    private static func renderStandalone<V: View>(
        _ rootView: V, probeSize: CGSize, scrollsToBottom: Bool = false
    ) throws -> Data {
        let hosting = NSHostingView(rootView:
            rootView
                .environment(\.colorScheme, .dark)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(.orange)
                .background(Color(nsColor: .windowBackgroundColor)))
        // 先に画面外へ置いて 1 度レイアウトしないと fittingSize が (0, 0) のままになる。
        hosting.frame = CGRect(origin: .zero, size: probeSize)
        let probeWindow = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                                   backing: .buffered, defer: false)
        probeWindow.contentView = hosting
        probeWindow.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        probeWindow.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width <= 0 { size.width = probeSize.width }
        if size.height <= 0 { size.height = probeSize.height }
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        // Form/List は `.frame(height:)` で高さを固定していても中身は NSScrollView に収まる
        // だけで、開いた DisclosureGroup の中身は下にスクロールしないと写らない。
        // 折りたたみを開いた状態の絵は、実際の操作と同じく末尾までスクロールしてから撮る。
        if scrollsToBottom {
            RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
            scrollToBottom(in: hosting)
        }

        return try capture(hosting, size: size)
    }

    /// 最初に見つかった `NSScrollView` を末尾まで送る。実際の操作と同じく、
    /// 折り返しの下にあるものを絵に入れるために使う。
    private static func scrollToBottom(in view: NSView) {
        guard let scrollView = firstScrollView(in: view) else { return }
        scrollView.layoutSubtreeIfNeeded()
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// ビュー階層を降りて最初に見つかった `NSScrollView`（Form/List の実体）を返す。
    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    /// `NSHostingView` を画面外のウィンドウで実描画させ、@2x の PNG データに焼く。
    private static func capture(_ view: NSHostingView<some View>, size: CGSize,
                                scrollsToBottom: Bool = false) throws -> Data {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        // SwiftUI の更新はランループ越しに走るので、描画が落ち着くまで回してから取り込む。
        RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
        // スクロールはレイアウトが確定してからでないと送り先の座標が出ない。
        if scrollsToBottom { scrollToBottom(in: view) }
        window.displayIfNeeded()

        // rep のピクセル数を論理サイズの 2 倍にし、size を論理サイズに戻すことで @2x になる。
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

    /// 生成用の設定を UserDefaults に積む。書き込み先は（Info.plist を持たない）このツール
    /// 自身のドメインなので、インストール済み Tokfuel.app の設定には触らない。
    private static func prepareDefaults() {
        let defaults = UserDefaults.standard
        // 以降の設定変更を記録させない（`~/Library/Application Support/Tokfuel` に何も書かない）。
        defaults.set(false, forKey: UsageEventLog.enabledKey)
        defaults.set(DisplayCurrency.usd.rawValue, forKey: Money.currencyKey)
        // UsageStore は集計期間とチャート形式を UserDefaults から復元する。プロパティ経由で
        // 変えると retok の再解析が走ってスピナーが写るため、初期化前にキーを直接書く。
        defaults.set(reportPeriod.rawValue, forKey: UsageStore.reportPeriodKey)
        defaults.set(CostChartStyle.daily.rawValue, forKey: UsageStore.costChartStyleKey)

        let settings = AppSettings.shared
        settings.budgetLimit = budgetLimit
        settings.dailyBudgetLimit = dailyBudgetLimit
        settings.budgetWarnPercent = 80
        settings.budgetPeriod = .calendarMonth
        // 並べて表示にして、TF-0032 の Cursor 二次ソースをヒーローに写す。
        settings.costSourceMode = .sideBySide
    }

    // MARK: - 合成（デスクトップ風の枠）

    /// メニューバー帯とポップオーバーをデスクトップ風の背景に合成した 1 枚。
    /// ポップオーバー本体は実物の `PopoverView` そのままで、枠だけがこのファイルの飾り。
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

    /// ステータス項目の見え方を伝えるためのメニューバー帯。金額はフィクスチャの「今日」を
    /// 本物と同じフォーマッタに通すので、指標「今日」× 表現「金額」の表示と一致する。
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

    /// ポップオーバーの器（角丸・縁・影）。NSPopover の見た目を絵の上で再現する。
    private static func popoverCard(store: UsageStore, updater: UpdateChecker) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return PopoverView(store: store, updater: updater)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }

    // MARK: - フィクスチャ

    /// 実データを読まずに描くための固定データ。日付だけは「今日」を基準にずらすので、
    /// ヒーローの金額（今日のコスト）が常に埋まる。
    static func fixtureStore() -> UsageStore {
        let store = UsageStore()
        store.report = fixtureReport()
        store.budgetSpend = budgetSpend
        // Cursor（二次ソース、TF-0032）。ヒーロー合計と内訳キャプションに出る今日ぶんだけ積む。
        store.driverDailyByID = ["cursor": [dateString(daysAgo: 0): cursorTodayCost]]
        // モデル別内訳は「節約のヒント」の Cursor 由来（TF-0078）の入力でもある。
        store.driverModelByID = ["cursor": cursorModelCosts]
        store.lastUpdated = Date()
        return store
    }

    /// Cursor の使用量 API に届かなかった状態。日別は空（＝ヒーローは Claude の分だけ）で、
    /// 金額の下に劣化の注意書きが出る絵になる。
    static func degradedCursorStore() -> UsageStore {
        degradedCursorStore(reason: .remoteUnavailable)
    }

    /// Cursor の取得が劣化した状態。`credentialsRejected` の絵にはサインインボタンが付く。
    static func degradedCursorStore(reason: CostSnapshot.Degradation) -> UsageStore {
        let store = fixtureStore()
        store.driverDailyByID = ["cursor": [:]]
        store.driverHealthByID = ["cursor": .degraded(reason)]
        return store
    }

    /// 「高コストのセッション」を写すためのフィクスチャ（TF-0077）。README の 1 枚目には
    /// 折り返しの下で入らないので、`popover-sessions` 画面だけがこちらを使う。
    static func sessionsFixtureStore() -> UsageStore {
        let store = fixtureStore()
        store.report = fixtureReport(topSessions: claudeTopSessions)
        store.driverSessionsByID = ["cursor": cursorSessions]
        return store
    }

    /// Claude（retok）側のセッション。Cursor 側と交互に並ぶ金額にして、マージの絵にする。
    static let claudeTopSessions: [RetokReport.TopSession] = [
        RetokReport.TopSession(session: "8f2c1a4b", project: "tokfuel/menu-bar-gauge",
                               cost: 18.42, prompts: 64, maxContext: 168_000),
        RetokReport.TopSession(session: "3b90de17", project: "tokfuel/cost-popover",
                               cost: 7.05, prompts: 22, maxContext: 92_000)
    ]

    /// Cursor（二次ソース）側の会話。ローカル DB からの推定なので UI に「推定」が付く。
    static var cursorSessions: [CostSnapshot.Session] {
        [
            CostSnapshot.Session(id: "0041d255", title: "SwiftUI のレイアウト崩れを直す",
                                 cost: 11.20, messages: 38, lastUsed: dateString(daysAgo: 0)),
            CostSnapshot.Session(id: "9c7ee301", title: CursorUsageReader.untitledSessionTitle,
                                 cost: 2.60, messages: 9, lastUsed: dateString(daysAgo: 2))
        ]
    }

    static func fixtureReport(topSessions: [RetokReport.TopSession] = []) -> RetokReport {
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
<<<<<<< HEAD
            // README には最初の 1 画面しか写らないが、`popover-advice` の絵は末尾まで
            // スクロールして撮る。retok 由来を 1 件置いて、Cursor 由来（CursorAdvice が
            // cursorModelCosts から作る）と並んだ状態——ソースバッジと severity 順——を写す。
            advice: [
                RetokReport.Advice(
                    severity: "medium",
                    key: "adv_model_mix",
                    title: "高価格モデルでの小粒セッションが 12 件 ($18.40)",
                    detail: "一問一答や軽い確認は Haiku/Sonnet で十分なことが多いです。"
                        + "/model で切り替えるか、軽い用途向けに別プロファイルを用意すると"
                        + "節約できます。")
            ],
            topSessions: []
=======
            // ポップオーバーはスクロールするが、README には最初の 1 画面しか写らない。
            // 節約のヒントは折り返しの下になるため空にしておく。高コストのセッションは
            // ui-preview の `popover-sessions` 画面だけが積む。
            advice: [],
            topSessions: topSessions
>>>>>>> origin/main
        )
    }

    /// 集計キーの日付文字列。書式は `UsageStore` に合わせる（ずれるとヒーローが「–」になる）。
    static func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return UsageStore.dateString(date)
    }
}
#endif
