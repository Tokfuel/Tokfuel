import Foundation
import SQLite3
import TokfuelCore

/// エンドポイントは非公式で変わり得るので、パースは防御的に行う。
/// `chargedCents` と `tokenUsage.totalCents` には名目額が入るので、そこだけを見ると
/// そこへ `cursorTokenFee` を足した内部値——実応答では従量課金イベントで 20〜35% 高く出る。
/// 価格表から取ったキャッシュだけを使うので、ここにハードコードした単価は無い。
/// 価格表に無いモデルは 0 のまま——金額 0 のイベントは合算にも表示にも出さない。
public enum CursorDashboardService {
    public typealias HTTPPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let endpoint =
        URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetFilteredUsageEvents")!
    private static let pageSize = 200
    private static let cacheTTL: TimeInterval = 120

    public struct Snapshot: Equatable {
        var daily: [String: Double]
        var byModel: [String: Double]
    }

    /// 取得の結果。`Snapshot?` では潰れてしまう 2 つの失敗を分ける——呼び出し側
    public enum FetchOutcome: Equatable {
        case success(Snapshot)
        case noCredentials
        case unauthorized
        case unreachable
    }

    private struct CacheEntry {
        let fetchedAt: Date
        let from: String
        let to: String
        let snapshot: Snapshot
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: CacheEntry?

    /// 成功かつイベント 0 件なら空辞書（ローカルへは落とさない——現行 Cursor の正解が 0 だから）。
    public static func dailyCosts(
        from: String,
        to: String,
        dbPath: String,
        now: Date = Date(),
        accessToken: String? = nil,
        session: HTTPPerformer? = nil
    ) async -> [String: Double]? {
        await fetchSnapshot(
            from: from, to: to, dbPath: dbPath, now: now,
            accessToken: accessToken, session: session
        )?.daily
    }

    /// 日別 + モデル別。同一キャッシュを共有するので `dailyCosts` の直後でも追加通信しない。
    public static func fetchSnapshot(
        from: String,
        to: String,
        dbPath: String,
        now: Date = Date(),
        accessToken: String? = nil,
        session: HTTPPerformer? = nil
    ) async -> Snapshot? {
        guard case .success(let snapshot) = await fetch(
            from: from, to: to, dbPath: dbPath, now: now,
            accessToken: accessToken, session: session
        ) else { return nil }
        return snapshot
    }

    public static func fetch(
        from: String,
        to: String,
        dbPath: String,
        now: Date = Date(),
        accessToken: String? = nil,
        session: HTTPPerformer? = nil
    ) async -> FetchOutcome {
        if let cached = cachedSnapshot(from: from, to: to, now: now) {
            return .success(cached)
        }
        guard let token = accessToken ?? readAccessToken(dbPath: dbPath), !token.isEmpty else {
            return .noCredentials
        }
        guard let range = epochMillisRange(from: from, to: to) else { return .unreachable }

        let performer = session ?? defaultPerformer
        let outcome = await fetchAllPages(
            token: token,
            startMillis: range.start,
            endMillis: range.end,
            perform: performer
        )
        guard case .success(let snapshot) = outcome else { return outcome }

        storeCache(from: from, to: to, snapshot: snapshot, now: now)
        return .success(snapshot)
    }


    public static func readAccessToken(dbPath: String) -> String? {
        guard let db = CursorSQLite.openReadOnly(path: dbPath) else { return nil }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let raw = sqlite3_column_text(stmt, 0)
        else { return nil }
        let token = String(cString: raw)
        return token.isEmpty ? nil : token
    }


    private static let defaultPerformer: HTTPPerformer = { request in
        try await URLSession.shared.data(for: request)
    }

    private static func fetchAllPages(
        token: String,
        startMillis: Int64,
        endMillis: Int64,
        perform: HTTPPerformer
    ) async -> FetchOutcome {
        var daily: [String: Double] = [:]
        var byModel: [String: Double] = [:]
        var page = 1
        var seen = 0
        var reportedTotal: Int?

        while page <= 50 {
            guard let body = requestBody(
                startMillis: startMillis,
                endMillis: endMillis,
                page: page
            ) else { return .unreachable }

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Tokfuel", forHTTPHeaderField: "User-Agent")
            request.httpBody = body

            guard let (data, response) = try? await perform(request),
                  let http = response as? HTTPURLResponse
            else { return .unreachable }
            if http.statusCode == 401 || http.statusCode == 403 { return .unauthorized }
            guard (200..<300).contains(http.statusCode),
                  let events = parseEventsResponse(data)
            else { return .unreachable }

            reportedTotal = events.totalCount
            for event in events.events {
                guard event.usd > 0 else { continue }
                if let date = dayString(fromTimestampMillis: event.timestampMillis) {
                    daily[date, default: 0] += event.usd
                }
                if let model = event.model, !model.isEmpty {
                    byModel[model, default: 0] += event.usd
                }
            }
            seen += events.events.count
            if events.events.isEmpty { break }
            if let total = reportedTotal, seen >= total { break }
            if events.events.count < pageSize { break }
            page += 1
        }
        return .success(Snapshot(daily: daily, byModel: byModel))
    }

    private static func requestBody(startMillis: Int64, endMillis: Int64, page: Int) -> Data? {
        let payload: [String: Any] = [
            "startDate": String(startMillis),
            "endDate": String(endMillis),
            "page": page,
            "pageSize": pageSize
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }


    public enum Charge: Equatable {
        /// 請求される（USD）。金額が 0 になる `billed` は作らない——`notCharged` に寄せる。
        case billed(Double)
        case notCharged

        var usd: Double {
            if case .billed(let usd) = self { return usd }
            return 0
        }

        /// 0 以下を `notCharged` に丸める。金額 0 の請求は表示にも合算にも出さないので、
        static func billing(_ usd: Double) -> Charge { usd > 0 ? .billed(usd) : .notCharged }
    }

    public struct ParsedEvent: Equatable {
        let timestampMillis: Double
        let usd: Double
        let model: String?
        let charge: Charge
    }

    public struct ParsedPage: Equatable {
        let totalCount: Int
        let events: [ParsedEvent]
    }

    public static func parseEventsResponse(_ data: Data) -> ParsedPage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let total = intValue(root["totalUsageEventsCount"]) ?? 0
        let rows = root["usageEventsDisplay"] as? [[String: Any]] ?? []
        let events: [ParsedEvent] = rows.compactMap { row in
            guard let millis = doubleValue(row["timestamp"]) else { return nil }
            let charge = charge(row)
            let model = (row["model"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ParsedEvent(
                timestampMillis: millis,
                usd: charge.usd,
                model: model,
                charge: charge)
        }
        return ParsedPage(totalCount: total, events: events)
    }

    /// 名目額が入るので、金額欄から先に読むと請求されない利用まで積み上がる（#100）。
    public static func charge(_ event: [String: Any]) -> Charge {
        let kind = (event["kind"] as? String)?.uppercased() ?? ""
        if kind.contains("INCLUDED") || kind.contains("NOT_CHARGED") { return .notCharged }
        if kind.contains("USAGE_BASED") {
            return .billing(billedUSD(event) ?? estimatedUSD(event))
        }
        if let dollars = costColumnUSD(event) {
            guard dollars > 0 else { return .notCharged }
            return .billing(billedUSD(event) ?? dollars)
        }
        return .billing(billedUSD(event) ?? estimatedUSD(event))
    }

    public static func billedUSD(_ event: [String: Any]) -> Double? {
        if let usage = event["tokenUsage"] as? [String: Any],
           let total = doubleValue(usage["totalCents"]) {
            return total / 100
        }
        if let dollars = costColumnUSD(event) { return dollars }
        if let charged = doubleValue(event["chargedCents"]) { return charged / 100 }
        return nil
    }

    public static func costColumnUSD(_ event: [String: Any]) -> Double? {
        guard let raw = event["usageBasedCosts"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "-" { return 0 }
        return Double(trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }

    /// ローカル走査（`CursorUsageReader`）とまったく同じ `CursorPricing` を通すので、
    /// 単価はここにも `CursorPricing` にもハードコードされていない——参照するのは
    /// キャッシュが空、またはモデルが表に無ければ 0（＝合算にも表示にも出さない）。
    /// `CursorPricing` は入出力の 2 本しか受けないので、入力単価で代用すると過大評価になる。
    public static func estimatedUSD(_ event: [String: Any]) -> Double {
        guard let usage = event["tokenUsage"] as? [String: Any] else { return 0 }
        let input = intValue(usage["inputTokens"]) ?? 0
        let output = intValue(usage["outputTokens"]) ?? 0
        guard input > 0 || output > 0 else { return 0 }
        return CursorPricing.cost(
            modelID: event["model"] as? String,
            inputTokens: input,
            outputTokens: output)
    }

    public static func epochMillisRange(from: String, to: String) -> (start: Int64, end: Int64)? {
        let calendar = Calendar.current
        guard let start = LocalDay.date(from: from, calendar: calendar),
              let endDayStart = LocalDay.date(from: to, calendar: calendar),
              let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endDayStart)
        else { return nil }
        return (
            Int64(start.timeIntervalSince1970 * 1000),
            Int64(end.timeIntervalSince1970 * 1000)
        )
    }

    public static func dayString(fromTimestampMillis millis: Double) -> String? {
        guard millis > 0 else { return nil }
        return LocalDay.string(from: Date(timeIntervalSince1970: millis / 1000))
    }


    private static func cachedSnapshot(from: String, to: String, now: Date) -> Snapshot? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let cache,
              cache.from == from, cache.to == to,
              now.timeIntervalSince(cache.fetchedAt) < cacheTTL
        else { return nil }
        return cache.snapshot
    }

    private static func storeCache(from: String, to: String, snapshot: Snapshot, now: Date) {
        cacheLock.lock()
        cache = CacheEntry(fetchedAt: now, from: from, to: to, snapshot: snapshot)
        cacheLock.unlock()
    }

    public static func resetCacheForTesting() {
        cacheLock.lock()
        cache = nil
        cacheLock.unlock()
    }


    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}
