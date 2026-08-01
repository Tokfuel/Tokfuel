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

    /// 取得の結果。`Snapshot?` では潰れてしまう 2 つの失敗を分ける——呼び出し側
    /// （`CursorCostDriver`）が「サインインしていない」と「API に届かない」を UI で
    /// 書き分けるために必要。
    enum FetchOutcome: Equatable {
        case success(Snapshot)
        /// `cursorAuth/accessToken` が無い（Cursor にサインインしていない）。
        case noCredentials
        /// トークンを送ったが拒否された（401 / 403）。`exp` が先でもサーバ側で失効している
        /// ことがある（実機で観測: `/oauth/token` が `shouldLogout: true` を返す状態）。
        case unauthorized
        /// 呼べなかった（オフライン・タイムアウト・応答形式の変化など）。
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
    /// 失敗理由が要るときは `fetch(...)` を使う。
    static func fetchSnapshot(
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

    /// 日別 + モデル別を、失敗理由まで残した形で返す。
    static func fetch(
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

    // MARK: - Token

    /// `ItemTable` の `cursorAuth/accessToken`。無ければ nil。
    static func readAccessToken(dbPath: String) -> String? {
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

    // MARK: - HTTP + pagination

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
            // 401 / 403 はトークンが死んでいる合図。オフラインと同じ扱いにすると
            // 「サインインし直せば直る」ことが UI に伝わらない。
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

    static func dayString(fromTimestampMillis millis: Double) -> String? {
        guard millis > 0 else { return nil }
        return LocalDay.string(from: Date(timeIntervalSince1970: millis / 1000))
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
