import Foundation
import Testing
@testable import Tokfuel

/// `CursorPricingService` のキャッシュを差し込んでからテスト本体を実行し、自分が足したキー
/// だけ剥がす（`setCachedRatesForTesting` は差分マージなので並行テストのキーは壊さない）。
private func withPricing(
    _ rates: [(key: String, input: Double, output: Double)],
    _ body: () -> Void
) {
    let cached = rates.map {
        CursorPricingService.CachedRate(key: $0.key, input: $0.input, output: $0.output)
    }
    CursorPricingService.setCachedRatesForTesting(cached)
    defer { CursorPricingService.removeCachedRatesForTesting(keys: rates.map(\.key)) }
    body()
}

struct CursorDashboardServiceParsingTests {
    /// 従量課金イベント。実応答では `chargedCents` = `totalCents` + `cursorTokenFee` で、
    /// Cursor 自身が Cost 列に出すのは `totalCents` 側（"$1.66"）。
    @Test func 従量課金はtotalCentsを請求額にする() {
        let event: [String: Any] = [
            "kind": "USAGE_EVENT_KIND_USAGE_BASED",
            "chargedCents": 204.688495,
            "cursorTokenFee": 39.0061,
            "usageBasedCosts": "$1.66",
            "tokenUsage": ["totalCents": 165.682395]
        ]
        guard case .billed(let usd) = CursorDashboardService.charge(event) else {
            Issue.record("従量課金として扱われていない")
            return
        }
        #expect(abs(usd - 1.65682395) < 0.0001)
    }

    @Test func プラン枠内は名目額があっても課金なし() {
        let event: [String: Any] = [
            "kind": "USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS",
            "chargedCents": 62.3386,
            "usageBasedCosts": "-",
            "tokenUsage": ["totalCents": 62.3386]
        ]
        #expect(CursorDashboardService.charge(event) == .notCharged)
    }

    @Test func エラーで無課金のイベントも課金なし() {
        let event: [String: Any] = [
            "kind": "USAGE_EVENT_KIND_ERRORED_NOT_CHARGED",
            "chargedCents": 411.38804,
            "usageBasedCosts": "-",
            "tokenUsage": ["totalCents": 249.70844]
        ]
        #expect(CursorDashboardService.charge(event) == .notCharged)
    }

    /// `kind` が無い旧応答・形式変更時の代替。Cost 列が "-" なら金額欄の名目額は使わない。
    @Test func kindが無くてもCost列が課金なしなら合算しない() {
        let event: [String: Any] = [
            "usageBasedCosts": "-",
            "tokenUsage": ["totalCents": 62.3386]
        ]
        #expect(CursorDashboardService.charge(event) == .notCharged)
    }

    @Test func kindもCost列も無ければ金額欄で判断する() {
        let event: [String: Any] = ["tokenUsage": ["totalCents": 59.7996]]
        guard case .billed(let usd) = CursorDashboardService.charge(event) else {
            Issue.record("金額欄から請求額を出せていない")
            return
        }
        #expect(abs(usd - 0.597996) < 0.0001)
    }

    /// 金額欄が無いイベントは、公式価格表のキャッシュでトークンから金額化する（#91）。
    @Test func 金額欄が無ければ価格表とトークンで金額化する() {
        withPricing([(key: "utest-dash-grok", input: 3, output: 15)]) {
            let event: [String: Any] = [
                "kind": "USAGE_EVENT_KIND_USAGE_BASED",
                "model": "utest-dash-grok-4.5-high-fast",
                "tokenUsage": ["inputTokens": 1_000_000, "outputTokens": 100_000]
            ]
            guard case .billed(let usd) = CursorDashboardService.charge(event) else {
                Issue.record("価格表から金額を出せていない")
                return
            }
            // 1M × $3 + 0.1M × $15 = $4.5
            #expect(abs(usd - 4.5) < 0.0001)
        }
    }

    /// 価格表に無いモデルは当て推量の単価を作らず 0 のまま——合算にも表示にも出さない。
    @Test func 価格表に無いモデルは課金なしに落とす() {
        let event: [String: Any] = [
            "kind": "USAGE_EVENT_KIND_USAGE_BASED",
            "model": "utest-dash-absent-model",
            "tokenUsage": ["inputTokens": 5_000, "outputTokens": 1_000]
        ]
        #expect(CursorDashboardService.charge(event) == .notCharged)
    }

    /// キャッシュ系のトークンは入力単価で代用しない（過大評価になる）。
    @Test func キャッシュトークンは金額に足さない() {
        withPricing([(key: "utest-dash-cache", input: 3, output: 15)]) {
            let event: [String: Any] = [
                "model": "utest-dash-cache-model",
                "tokenUsage": [
                    "inputTokens": 1_000_000, "outputTokens": 0,
                    "cacheReadTokens": 9_000_000, "cacheWriteTokens": 1_000_000
                ]
            ]
            #expect(abs(CursorDashboardService.estimatedUSD(event) - 3.0) < 0.0001)
        }
    }

    @Test func 金額もトークンも無ければ課金なし() {
        #expect(CursorDashboardService.charge([:]) == .notCharged)
    }

    @Test func イベントページをパースできる() throws {
        let json = """
        {
          "totalUsageEventsCount": 3,
          "usageEventsDisplay": [
            {
              "timestamp": "1785410348371",
              "kind": "USAGE_EVENT_KIND_USAGE_BASED",
              "chargedCents": 130,
              "tokenUsage": { "totalCents": 100 }
            },
            {
              "timestamp": "1785410348371",
              "tokenUsage": { "totalCents": 50 }
            },
            {
              "timestamp": "1785410348371",
              "model": "cursor-grok-4.5-high-fast",
              "kind": "USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS",
              "usageBasedCosts": "-",
              "tokenUsage": {
                "inputTokens": 100, "outputTokens": 20,
                "cacheReadTokens": 880, "totalCents": 62.3
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let page = try #require(CursorDashboardService.parseEventsResponse(json))
        #expect(page.totalCount == 3)
        #expect(page.events.count == 3)
        #expect(page.events[0].usd == 1.0)
        #expect(page.events[1].usd == 0.5)
        #expect(page.events[2].usd == 0)
        #expect(page.events[2].charge == .notCharged)
        #expect(page.events[0].timestampMillis == 1_785_410_348_371)
    }

    @Test func 壊れたJSONはnil() {
        #expect(CursorDashboardService.parseEventsResponse(Data("{".utf8)) == nil)
    }

    @Test func 日付範囲をepochミリ秒に落とせる() throws {
        let range = try #require(
            CursorDashboardService.epochMillisRange(from: "2026-07-30", to: "2026-07-30")
        )
        #expect(range.start < range.end)
        let startDay = CursorDashboardService.dayString(fromTimestampMillis: Double(range.start))
        let endDay = CursorDashboardService.dayString(fromTimestampMillis: Double(range.end))
        #expect(startDay == "2026-07-30")
        #expect(endDay == "2026-07-30")
    }
}

/// キャッシュ（`CursorDashboardService` の static な共有状態）のキーは (from, to)。
/// 並行実行されるテストが同じ窓を使うと互いの結果を拾ってしまうので、テストごとに違う窓を使う。
/// イベントの日付は API 応答の timestamp だけで決まるため、窓をずらしても検証内容は変わらない。
private func uniqueWindow(daysAgo: Int) -> (from: String, to: String) {
    let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    let string = UsageStore.dateString(day)
    return (string, string)
}

struct CursorDashboardServiceFetchTests {
    @Test func HTTP成功なら日別に合算する() async throws {
        CursorDashboardService.resetCacheForTesting()
        let window = uniqueWindow(daysAgo: 100)
        let today = UsageStore.dateString(Date())
        let millis = Int64(Date().timeIntervalSince1970 * 1000)
        let payload = """
        {
          "totalUsageEventsCount": 2,
          "usageEventsDisplay": [
            { "timestamp": "\(millis)", "chargedCents": 250 },
            { "timestamp": "\(millis)", "chargedCents": 50 }
          ]
        }
        """.data(using: .utf8)!

        let daily = await CursorDashboardService.dailyCosts(
            from: window.from,
            to: window.to,
            dbPath: "/nonexistent/state.vscdb",
            accessToken: "test-token",
            session: { request in
                let auth = request.value(forHTTPHeaderField: "Authorization")
                let response = HTTPURLResponse(
                    url: URL(string: "https://api2.cursor.sh/")!,
                    statusCode: auth == "Bearer test-token" ? 200 : 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (payload, response)
            }
        )
        let result = try #require(daily)
        #expect(abs((result[today] ?? 0) - 3.0) < 0.0001)
    }

    /// #100: プラン枠内のイベントは金額にも内訳にも乗らない。
    /// #91: 金額欄が無いイベントは公式価格表でトークンから金額化して合算に乗せる。
    @Test func プラン枠内は合算せず金額欄が無いぶんは価格表で金額化する() async throws {
        CursorDashboardService.resetCacheForTesting()
        let window = uniqueWindow(daysAgo: 104)
        let today = UsageStore.dateString(Date())
        let millis = Int64(Date().timeIntervalSince1970 * 1000)
        let payload = """
        {
          "totalUsageEventsCount": 4,
          "usageEventsDisplay": [
            {
              "timestamp": "\(millis)",
              "model": "utest-fetch-grok-4.5-high-fast",
              "kind": "USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS",
              "usageBasedCosts": "-",
              "chargedCents": 62.3386,
              "tokenUsage": {
                "inputTokens": 5467, "outputTokens": 1919,
                "cacheReadTokens": 566976, "totalCents": 62.3386
              }
            },
            {
              "timestamp": "\(millis)",
              "model": "utest-fetch-composer-2.5-fast",
              "tokenUsage": { "inputTokens": 1000000, "outputTokens": 100000 }
            },
            {
              "timestamp": "\(millis)",
              "model": "utest-fetch-absent-model",
              "tokenUsage": { "inputTokens": 400, "outputTokens": 100 }
            },
            {
              "timestamp": "\(millis)",
              "model": "utest-fetch-sonnet",
              "kind": "USAGE_EVENT_KIND_USAGE_BASED",
              "usageBasedCosts": "$0.65",
              "chargedCents": 94.61751,
              "tokenUsage": { "outputTokens": 3851, "totalCents": 65.430135 }
            }
          ]
        }
        """.data(using: .utf8)!

        let rates = [
            CursorPricingService.CachedRate(key: "utest-fetch-grok", input: 3, output: 15),
            CursorPricingService.CachedRate(key: "utest-fetch-composer", input: 1, output: 5)
        ]
        CursorPricingService.setCachedRatesForTesting(rates)
        defer { CursorPricingService.removeCachedRatesForTesting(keys: rates.map(\.key)) }

        let result = try #require(await CursorDashboardService.fetchSnapshot(
            from: window.from,
            to: window.to,
            dbPath: "/nonexistent/state.vscdb",
            accessToken: "test-token",
            session: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://api2.cursor.sh/")!,
                    statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (payload, response)
            }
        ))
        // プラン枠内の 62.3386 セントは乗らない。従量課金の $0.65430135 と、金額欄が無い
        // composer の 1M × $1 + 0.1M × $5 = $1.5 だけが合算される。
        #expect(abs((result.daily[today] ?? 0) - 2.15430135) < 0.0001)
        #expect(result.byModel.keys.sorted()
                == ["utest-fetch-composer-2.5-fast", "utest-fetch-sonnet"])
        // 価格表に無いモデルは 0 のままなので、内訳に $0 の行を作らない。
        #expect(result.byModel["utest-fetch-absent-model"] == nil)
        #expect(result.byModel["utest-fetch-grok-4.5-high-fast"] == nil)
    }

    @Test func HTTP失敗ならnilでローカルへ落とせる() async {
        CursorDashboardService.resetCacheForTesting()
        let window = uniqueWindow(daysAgo: 101)
        let today = UsageStore.dateString(Date())
        let daily = await CursorDashboardService.dailyCosts(
            from: window.from,
            to: window.to,
            dbPath: "/nonexistent/state.vscdb",
            accessToken: "test-token",
            session: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://api2.cursor.sh/")!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data("{\"error\":\"not_authenticated\"}".utf8), response)
            }
        )
        #expect(daily == nil)
    }

    @Test func トークンもセッションも無ければnil() async {
        CursorDashboardService.resetCacheForTesting()
        let window = uniqueWindow(daysAgo: 102)
        let today = UsageStore.dateString(Date())
        let daily = await CursorDashboardService.dailyCosts(
            from: window.from,
            to: window.to,
            dbPath: "/nonexistent/state.vscdb"
        )
        #expect(daily == nil)
    }

    @Test func 成功してイベント0件なら空辞書() async throws {
        CursorDashboardService.resetCacheForTesting()
        let window = uniqueWindow(daysAgo: 103)
        let today = UsageStore.dateString(Date())
        let payload = Data("{\"totalUsageEventsCount\":0,\"usageEventsDisplay\":[]}".utf8)
        let daily = await CursorDashboardService.dailyCosts(
            from: window.from,
            to: window.to,
            dbPath: "/nonexistent/state.vscdb",
            accessToken: "test-token",
            session: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://api2.cursor.sh/")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (payload, response)
            }
        )
        let result = try #require(daily)
        #expect(result.isEmpty)
    }
}
