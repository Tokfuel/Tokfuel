#if DEBUG
import AppKit
import SwiftUI

/// README に貼るスクリーンショット (`assets/screenshot.png`) を、実物の `PopoverView` から
/// 生成する（TF-0015）。手描きのモックアップと違い、UI を変えれば絵も追従する。
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
    /// フィクスチャの集計期間（日）。期間ピッカーの選択位置にもそのまま出る。
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

    enum RenderError: LocalizedError {
        case usage
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .usage: return "usage: Tokfuel --screenshot <output.png>"
            case .renderFailed: return "PopoverView のレンダリングに失敗しました"
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
            try renderPNG().write(to: url)
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

    /// フィクスチャを積んだポップオーバーを @2x で PNG にする。
    ///
    /// `ImageRenderer` ではなく `NSHostingView` を実際に描画させる。`ImageRenderer` は
    /// `ScrollView` の中身と AppKit 実装のコントロール（フッターの `Menu`・期間ピッカー）を
    /// 描けず、本文が空の絵になるため。
    private static func renderPNG() throws -> Data {
        let view = NSHostingView(rootView: composition(store: fixtureStore(), now: Date()))
        view.frame = CGRect(origin: .zero, size: canvas)

        // 画面外のウィンドウに載せて表示させる（SwiftUI に実レイアウトと実描画をさせるため）。
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        // SwiftUI の更新はランループ越しに走るので、描画が落ち着くまで回してから取り込む。
        RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
        window.displayIfNeeded()

        // rep のピクセル数を論理サイズの 2 倍にし、size を論理サイズに戻すことで @2x になる。
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvas.width * 2), pixelsHigh: Int(canvas.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            throw RenderError.renderFailed
        }
        rep.size = canvas
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
        // UsageStore は集計期間を UserDefaults から復元する。プロパティ経由で変えると
        // retok の再解析が走ってスピナーが写るため、初期化前にキーを直接書く。
        defaults.set(reportDays, forKey: "reportDays")

        let settings = AppSettings.shared
        settings.budgetLimit = budgetLimit
        settings.dailyBudgetLimit = dailyBudgetLimit
        settings.budgetWarnPercent = 80
        settings.budgetPeriod = .calendarMonth
    }

    // MARK: - 合成（デスクトップ風の枠）

    /// メニューバー帯とポップオーバーをデスクトップ風の背景に合成した 1 枚。
    /// ポップオーバー本体は実物の `PopoverView` そのままで、枠だけがこのファイルの飾り。
    private static func composition(store: UsageStore, now: Date) -> some View {
        VStack(spacing: 0) {
            menuBar(store: store, now: now)
            popoverCard(store: store)
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

    /// ステータス項目の見え方を伝えるためのメニューバー帯。金額は本物と同じ
    /// フォーマッタを通すので、`menuBarDisplay == .cost` の表示と一致する。
    private static func menuBar(store: UsageStore, now: Date) -> some View {
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
                Text(store.todayCost.map { PopoverView.money($0) } ?? "–")
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
    private static func popoverCard(store: UsageStore) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return PopoverView(store: store)
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
        // コスト用ポップオーバーが読むのはプロンプト数とセッション数だけ。
        store.daily = [DailyUsage(date: dateString(daysAgo: 0), prompts: 42, sessions: 6)]
        store.lastUpdated = Date()
        return store
    }

    static func fixtureReport() -> RetokReport {
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
            perModel: modelCosts.mapValues {
                // 絵に出るのはコストだけなので、トークン数はコストから機械的に置く。
                .init(cost: $0, input: Int($0 * 10_800), output: Int($0 * 890),
                      requests: Int($0 * 6))
            },
            daily: daily,
            // ポップオーバーはスクロールするが、README には最初の 1 画面しか写らない。
            // 高コストのセッションと節約のヒントは折り返しの下になるため空にしておく。
            advice: [],
            topSessions: []
        )
    }

    /// 集計キーの日付文字列。書式は `UsageStore` に合わせる（ずれるとヒーローが「–」になる）。
    static func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return UsageStore.dateString(date)
    }
}
#endif
