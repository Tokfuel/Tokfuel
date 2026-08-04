#if DEBUG
import AppKit
import SwiftUI

/// 実機確認用: Cursor 二次ソースが今日コストに乗るかを PNG と stdout で検証する。
///
/// ```
/// TOKFUEL_CURSOR_DB=.../fixture.sqlite \
///   Tokfuel --verify-cursor-ui /tmp/cursor-ui.png
/// ```
///
/// 配布ビルドには含まれない。`ScreenshotRenderer` と同じ NSHostingView 描画経路を使い、
/// フィクスチャではなく `CursorCostDriver` の実スキャン結果を `UsageStore` に載せる。
@MainActor
enum VerifyCursorUI {
    static func runAndExit(arguments: [String] = CommandLine.arguments) -> Never {
        guard let path = outputPath(arguments: arguments) else {
            fputs("usage: Tokfuel --verify-cursor-ui <output.png>\n", stderr)
            exit(1)
        }
        // applicationDidFinishLaunching（MainActor）から呼ばれるので、semaphore で
        // MainActor を塞ぐと Task が進めずデッドロックする。RunLoop を回して待つ。
        var result: Result<Data, Error>?
        Task { @MainActor in
            do {
                result = .success(try await render(to: URL(fileURLWithPath: path)))
            } catch {
                result = .failure(error)
            }
            CFRunLoopStop(CFRunLoopGetMain())
        }
        while result == nil {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        switch result! {
        case .success(let png):
            do {
                try png.write(to: URL(fileURLWithPath: path))
                print("wrote \(path)")
                exit(0)
            } catch {
                fputs(error.localizedDescription + "\n", stderr)
                exit(1)
            }
        case .failure(let error):
            fputs(error.localizedDescription + "\n", stderr)
            exit(1)
        }
    }

    nonisolated static func outputPath(arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--verify-cursor-ui") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    private static func render(to url: URL) async throws -> Data {
        let driver = CursorCostDriver()
        print("cursorDB:", driver.stateDBURL.path)
        print("isAvailable:", driver.isAvailable)

        let today = UsageStore.dateString(Date())
        let from = UsageStore.dateString(
            Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        )
        // CostDriver 本番経路（ダッシュボード優先 → ローカルフォールバック）
        CursorDashboardService.resetCacheForTesting()
        let snapshot = await driver.snapshot(from: from, to: today)
        let daily = snapshot.daily
        let todayCost = daily[today] ?? 0
        print("today:", today)
        print("cursorTodayCost:", todayCost)
        print("cursorDays:", daily.count)
        print("cursorTotal:", daily.values.reduce(0, +))
        print("health:", snapshot.health)
        // 請求されなかったぶん・金額を出せなかったぶん（#100 / #91）。金額 0 の説明がここに出る。
        print("unbilledModels:", snapshot.unbilled.tokensByModel)
        print("unbilledToday:", snapshot.unbilled.includes(day: today))
        print("unpricedModels:", snapshot.unpriced.tokensByModel)
        print("hasAccessToken:", CursorDashboardService.readAccessToken(dbPath: driver.stateDBURL.path) != nil)

        let store = UsageStore()
        // 日別だけでなく health も載せる。そうしないと「取れなかった $0」の注意書きが絵に出ない。
        store.applyDriverSnapshots([driver.id: snapshot])
        store.report = minimalReport(todayClaude: 1.23)
        store.daily = [DailyUsage(date: today, prompts: 3, sessions: 1)]
        store.lastUpdated = Date()

        let breakdown = store.driverBreakdown
        print("driverBreakdown:", breakdown)
        print("unbilledNotices:", store.unbilledSourceNotices.map(\.message))
        print("unpricedNotices:", store.unpricedSourceNotices.map(\.message))
        print("todayCost(combined):", store.todayCost)
        if todayCost > 0 {
            print("VERIFY_OK: Cursor folded into combined total "
                  + "\(PopoverView.money(store.todayCost)) (no separate caption)")
        } else {
            print("VERIFY_EMPTY: no positive Cursor cost for today")
        }

        let view = NSHostingView(
            rootView: PopoverView(store: store)
                .tint(.orange)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.colorScheme, .dark)
        )
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 520)

        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        // async 文脈では RunLoop.run(until:) が使えないので、描画が落ち着くのを待つ。
        try await Task.sleep(nanoseconds: 600_000_000)
        window.displayIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 720, pixelsHigh: 1040,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            throw NSError(domain: "VerifyCursorUI", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bitmap failed"])
        }
        rep.size = CGSize(width: 360, height: 520)
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "VerifyCursorUI", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "png failed"])
        }
        _ = url
        return png
    }

    private static func minimalReport(todayClaude: Double) -> RetokReport {
        let today = UsageStore.dateString(Date())
        return RetokReport(
            periodDays: 7,
            filesScanned: 1,
            totals: RetokReport.Totals(
                cost: todayClaude, input: 1000, output: 100,
                cacheRead: 0, cacheWrite: 0, prompts: 3, requests: 3
            ),
            cacheHitRate: 0,
            perModel: ["claude-sonnet-4-5": RetokReport.ModelUsage(
                cost: todayClaude, input: 1000, output: 100, requests: 3
            )],
            daily: [today: RetokReport.DailyCost(cost: todayClaude, output: 100)],
            advice: [],
            topSessions: []
        )
    }
}
#endif
