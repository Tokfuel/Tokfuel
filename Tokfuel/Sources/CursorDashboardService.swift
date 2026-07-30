import Foundation
import SQLite3

/// Cursor 3.x 以降、ローカル `state.vscdb` の `tokenCount` はほぼ常に 0 になる。
/// 代わりに Cursor アプリが既に持つセッション（`ItemTable.cursorAuth/accessToken`）で
/// `api2.cursor.sh` の非公式ダッシュボード API を呼び、日別コストを取る。
///
/// - **Zero setup**: クッキーの手貼りは不要。Cursor にログイン済みならそのまま動く。
/// - **送るもの**: Authorization ヘッダと日付範囲だけ。プロンプト本文やローカル履歴は送らない。
/// - **失敗時**: `nil` を返し、呼び出し側（`CursorCostDriver`）がローカル SQLite に落ちる。
///
/// エンドポイントは非公式で変わり得る。パースは防御的に、金額は `chargedCents` 優先
/// （無ければ `tokenUsage.totalCents`）。単位はセント → USD。
enum CursorDashboardService {
    /// 注入可能な HTTP 実行口。テストではスタブを渡す。
    typealias HTTPPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let endpoint =
        URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetFilteredUsageEvents")!
    private static let pageSize = 200
    private static let cacheTTL: TimeInterval = 120

    struct Snapshot: Equatable {
        var daily: [String: Double]
        /// 期間合計のモデル別コスト（キーは API の model 文字列）。
        var byModel: [String: Double]
    }

    private struct CacheEntry {
        let fetchedAt: Date
        let from: String
        let to: String
        let snapshot: Snapshot
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: CacheEntry?

    /// 認証済みで取れた日別コスト。失敗時は `nil`（ローカルへフォールバック）。
    /// 成功かつイベント 0 件なら空辞書（ローカルへは落とさない——現行 Cursor の正解が 0 だから）。
    ///
    /// - Parameter accessToken: テスト用の上書き。未指定なら `dbPath` の ItemTable から読む。
    static func dailyCosts(
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
    static func fetchSnapshot(
        from: String,
        to: String,
        dbPath: String,
        now: Date = Date(),
        accessToken: String? = nil,
        session: HTTPPerformer? = nil
    ) async -> Snapshot? {
        if let cached = cachedSnapshot(from: from, to: to, now: now) {
            return cached
        }
        guard let token = accessToken ?? readAccessToken(dbPath: dbPath), !token.isEmpty else {
            return nil
        }
        guard let range = epochMillisRange(from: from, to: to) else { return nil }

        let performer = session ?? defaultPerformer
        guard let snapshot = await fetchAllPages(
            token: token,
            startMillis: range.start,
            endMillis: range.end,
            perform: performer
        ) else { return nil }

        storeCache(from: from, to: to, snapshot: snapshot, now: now)
        return snapshot
    }

    // MARK: - Token

    /// `ItemTable` の `cursorAuth/accessToken`。無ければ nil。
    static func readAccessToken(dbPath: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
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

    // MARK: - HTTP + pagination

    private static let defaultPerformer: HTTPPerformer = { request in
        try await URLSession.shared.data(for: request)
    }

    private static func fetchAllPages(
        token: String,
        startMillis: Int64,
        endMillis: Int64,
        perform: HTTPPerformer
    ) async -> Snapshot? {
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
            ) else { return nil }

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Tokfuel", forHTTPHeaderField: "User-Agent")
            request.httpBody = body

            guard let (data, response) = try? await perform(request),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let events = parseEventsResponse(data)
            else { return nil }

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
        return Snapshot(daily: daily, byModel: byModel)
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

    // MARK: - Parsing (testable)

    struct ParsedEvent: Equatable {
        let timestampMillis: Double
        let usd: Double
        let model: String?
    }

    struct ParsedPage: Equatable {
        let totalCount: Int
        let events: [ParsedEvent]
    }

    /// ダッシュボード JSON 1 ページを日別集計前のイベント列に落とす。
    static func parseEventsResponse(_ data: Data) -> ParsedPage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let total = intValue(root["totalUsageEventsCount"]) ?? 0
        let rows = root["usageEventsDisplay"] as? [[String: Any]] ?? []
        let events: [ParsedEvent] = rows.compactMap { row in
            guard let millis = doubleValue(row["timestamp"]) else { return nil }
            let usd = centsToUSD(row)
            let model = (row["model"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ParsedEvent(timestampMillis: millis, usd: usd, model: model)
        }
        return ParsedPage(totalCount: total, events: events)
    }

    /// `chargedCents` → なければ `tokenUsage.totalCents`。どちらも無ければ 0。
    static func centsToUSD(_ event: [String: Any]) -> Double {
        if let charged = doubleValue(event["chargedCents"]) {
            return charged / 100
        }
        if let usage = event["tokenUsage"] as? [String: Any],
           let total = doubleValue(usage["totalCents"]) {
            return total / 100
        }
        return 0
    }

    /// ローカル日付の [from, to] → API 用 epoch ミリ秒（その日の始端〜終端）。
    static func epochMillisRange(from: String, to: String) -> (start: Int64, end: Int64)? {
        guard let startDay = parseDay(from), let endDay = parseDay(to) else { return nil }
        let calendar = Calendar.current
        guard let start = calendar.date(from: startDay),
              let endDayStart = calendar.date(from: endDay),
              let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endDayStart)
        else { return nil }
        return (
            Int64(start.timeIntervalSince1970 * 1000),
            Int64(end.timeIntervalSince1970 * 1000)
        )
    }

    static func dayString(fromTimestampMillis millis: Double) -> String? {
        guard millis > 0 else { return nil }
        return UsageStore.dateString(Date(timeIntervalSince1970: millis / 1000))
    }

    // MARK: - Cache

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

    /// テスト用にキャッシュを消す。
    static func resetCacheForTesting() {
        cacheLock.lock()
        cache = nil
        cacheLock.unlock()
    }

    // MARK: - Helpers

    private static func parseDay(_ ymd: String) -> DateComponents? {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return DateComponents(calendar: Calendar.current, year: y, month: m, day: d)
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
