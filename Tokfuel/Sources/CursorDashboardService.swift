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
/// エンドポイントは非公式で変わり得るので、パースは防御的に行う。
///
/// **金額の決め方**（実応答で確認した形。#91 / #100）: イベントは `kind` に課金区分を持ち、
/// `USAGE_EVENT_KIND_USAGE_BASED` だけが実際に請求される。
/// `..._INCLUDED_IN_BUSINESS` などのプラン枠内と `..._ERRORED_NOT_CHARGED` の無課金でも
/// `chargedCents` と `tokenUsage.totalCents` には名目額が入るので、そこだけを見ると
/// 請求されない利用まで積み上がる。区分は必ず先に見る。
///
/// 請求額そのものは `tokenUsage.totalCents` を使う。Cursor 自身がダッシュボードの Cost 列
/// （CSV の `Cost`、応答では `usageBasedCosts`）に出すのはこの値で、`chargedCents` は
/// そこへ `cursorTokenFee` を足した内部値——実応答では従量課金イベントで 20〜35% 高く出る。
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
        /// 使ったが請求されないイベント（プラン枠内・無課金）の記録。金額には入れない。
        var unbilled = CostSnapshot.UnbilledUsage()
        /// 金額を出せなかったイベントの記録。金額には入れない。
        var unpriced = CostSnapshot.UnbilledUsage()
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
        var unbilled = CostSnapshot.UnbilledUsage()
        var unpriced = CostSnapshot.UnbilledUsage()
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
                let date = dayString(fromTimestampMillis: event.timestampMillis)
                switch event.charge {
                case .billed(let usd):
                    guard usd > 0 else { continue }
                    if let date { daily[date, default: 0] += usd }
                    if let model = event.model, !model.isEmpty {
                        byModel[model, default: 0] += usd
                    }
                case .unbilled:
                    // 請求されないので金額は 0 のまま。ただし「使っていない」でもないので、
                    // どのモデルで何トークン使ったかだけ残して UI が言い分けられるようにする。
                    guard event.tokens > 0 else { continue }
                    unbilled.add(model: event.model, day: date, tokens: event.tokens)
                case .unknown:
                    guard event.tokens > 0 else { continue }
                    unpriced.add(model: event.model, day: date, tokens: event.tokens)
                }
            }
            seen += events.events.count
            if events.events.isEmpty { break }
            if let total = reportedTotal, seen >= total { break }
            if events.events.count < pageSize { break }
            page += 1
        }
        return .success(Snapshot(daily: daily, byModel: byModel,
                                unbilled: unbilled, unpriced: unpriced))
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

    /// イベント 1 件の課金区分。応答の `kind`（CSV の `Kind` 列に対応）から決める。
    enum Charge: Equatable {
        /// 従量課金として実際に請求される（USD）。
        case billed(Double)
        /// 使ったが請求されない（プランの included 枠、エラーで無課金）。
        case unbilled
        /// 区分も金額も読めなかった。0 として扱うが「請求が無い」とは言えない。
        case unknown

        /// 合算に入れる金額。請求されないぶんと不明なぶんは 0。
        var usd: Double {
            if case .billed(let usd) = self { return usd }
            return 0
        }
    }

    struct ParsedEvent: Equatable {
        let timestampMillis: Double
        /// 請求額 (USD)。`charge` が `.billed` 以外なら 0。
        let usd: Double
        let model: String?
        let charge: Charge
        /// このイベントのトークン数合計。金額が付かないぶんの規模として注意書きに使う。
        let tokens: Int
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
            let charge = charge(row)
            let model = (row["model"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ParsedEvent(
                timestampMillis: millis,
                usd: charge.usd,
                model: model,
                charge: charge,
                tokens: tokenCount(row))
        }
        return ParsedPage(totalCount: total, events: events)
    }

    /// イベントの課金区分と、請求されるなら金額。
    ///
    /// `kind` を最優先する。included 枠内・無課金でも `chargedCents` / `totalCents` には
    /// 名目額が入るので、金額欄から先に読むと請求されない利用まで積み上がる（#100）。
    /// `kind` が無い（旧応答・形式変更）ときは Cost 列（`usageBasedCosts`）へ落ち、
    /// そこも読めなければ金額欄だけで従来どおり判断する。
    static func charge(_ event: [String: Any]) -> Charge {
        let kind = (event["kind"] as? String)?.uppercased() ?? ""
        if kind.contains("INCLUDED") || kind.contains("NOT_CHARGED") { return .unbilled }
        if kind.contains("USAGE_BASED") {
            guard let usd = billedUSD(event) else { return .unknown }
            return usd > 0 ? .billed(usd) : .unbilled
        }
        // 区分が読めない場合の代替。Cost 列が "-"（課金なし）なら金額欄の名目額は使わない。
        if let dollars = costColumnUSD(event) {
            guard dollars > 0 else { return .unbilled }
            return .billed(billedUSD(event) ?? dollars)
        }
        guard let usd = billedUSD(event) else { return .unknown }
        return usd > 0 ? .billed(usd) : .unbilled
    }

    /// 請求額 (USD)。`tokenUsage.totalCents` を正とし、無ければ Cost 列、
    /// 最後に `chargedCents`（`cursorTokenFee` を含む内部値）へ落ちる。
    static func billedUSD(_ event: [String: Any]) -> Double? {
        if let usage = event["tokenUsage"] as? [String: Any],
           let total = doubleValue(usage["totalCents"]) {
            return total / 100
        }
        if let dollars = costColumnUSD(event) { return dollars }
        if let charged = doubleValue(event["chargedCents"]) { return charged / 100 }
        return nil
    }

    /// `usageBasedCosts`（ダッシュボードの Cost 列）を USD にする。
    /// 課金なしを表す "-" は 0、欄が無い・読めない場合は nil。
    static func costColumnUSD(_ event: [String: Any]) -> Double? {
        guard let raw = event["usageBasedCosts"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "-" { return 0 }
        return Double(trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }

    /// イベントのトークン数合計。金額が付かないイベントの「規模」を示すだけなので、
    /// 入力・出力・キャッシュを区別せず足す。
    static func tokenCount(_ event: [String: Any]) -> Int {
        guard let usage = event["tokenUsage"] as? [String: Any] else { return 0 }
        return ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens"]
            .compactMap { intValue(usage[$0]) }
            .reduce(0, +)
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
