import Foundation
import Testing
@testable import Tokfuel

struct CursorDashboardServiceParsingTests {
    @Test func chargedCentsを優先してUSDにする() {
        let event: [String: Any] = [
            "chargedCents": 124.73,
            "tokenUsage": ["totalCents": 100.0]
        ]
        #expect(abs(CursorDashboardService.centsToUSD(event) - 1.2473) < 0.0001)
    }

    @Test func chargedCentsが無ければtokenUsage_totalCents() {
        let event: [String: Any] = [
            "tokenUsage": ["totalCents": 59.7996]
        ]
        #expect(abs(CursorDashboardService.centsToUSD(event) - 0.597996) < 0.0001)
    }

    @Test func 金額フィールドが無ければゼロ() {
        #expect(CursorDashboardService.centsToUSD([:]) == 0)
    }

    @Test func イベントページをパースできる() throws {
        let json = """
        {
          "totalUsageEventsCount": 2,
          "usageEventsDisplay": [
            {
              "timestamp": "1785410348371",
              "chargedCents": 100,
              "tokenUsage": { "totalCents": 50 }
            },
            {
              "timestamp": "1785410348371",
              "tokenUsage": { "totalCents": 50 }
            }
          ]
        }
        """.data(using: .utf8)!
        let page = try #require(CursorDashboardService.parseEventsResponse(json))
        #expect(page.totalCount == 2)
        #expect(page.events.count == 2)
        #expect(page.events[0].usd == 1.0)
        #expect(page.events[1].usd == 0.5)
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

struct CursorDashboardServiceFetchTests {
    @Test func HTTP成功なら日別に合算する() async throws {
        CursorDashboardService.resetCacheForTesting()
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
            from: today,
            to: today,
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

    @Test func HTTP失敗ならnilでローカルへ落とせる() async {
        CursorDashboardService.resetCacheForTesting()
        let today = UsageStore.dateString(Date())
        let daily = await CursorDashboardService.dailyCosts(
            from: today,
            to: today,
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
        let today = UsageStore.dateString(Date())
        let daily = await CursorDashboardService.dailyCosts(
            from: today,
            to: today,
            dbPath: "/nonexistent/state.vscdb"
        )
        #expect(daily == nil)
    }

    @Test func 成功してイベント0件なら空辞書() async throws {
        CursorDashboardService.resetCacheForTesting()
        let today = UsageStore.dateString(Date())
        let payload = Data("{\"totalUsageEventsCount\":0,\"usageEventsDisplay\":[]}".utf8)
        let daily = await CursorDashboardService.dailyCosts(
            from: today,
            to: today,
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
