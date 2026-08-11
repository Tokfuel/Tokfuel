import Foundation
import SQLite3
import TokfuelCore

/// Cursor 使用量を二次コスト源として読む CostDriver。
///
/// **優先経路（Cursor 3.x 以降の本命）**: アプリが持つ `cursorAuth/accessToken` で
/// `api2.cursor.sh` のダッシュボード API を呼び、請求側のイベントから日別コストを取る
/// （`CursorDashboardService`）。ローカル DB の `tokenCount` は現行 Cursor ではほぼ 0 のまま
/// 残るため、こちらが無いと今日の使用が常に $0 になる。
///
/// **フォールバック**: API が使えないとき（未ログイン・オフライン・401 等）だけ、
/// `state.vscdb` の `bubbleId:*` / `tokenCount` を読む旧来経路。スナップショットが残っている
/// 古い会話分の下限推定になる。
///
/// UI ではどちら経由でも「推定」と出す——プラン込み枠の換算や非公式 API の揺らぎがあるため。
///
/// フォールバックへ落ちたときは `CostSnapshot.health` を `.degraded` にする。金額は 0 でも
/// 「使っていない」ではなく「取れていない」ので、UI がその 2 つを書き分けられるようにする。
public struct CursorCostDriver {
    public let id = "cursor"
    public let displayName = "Cursor"
    public let stateDBURL: URL

    /// ダッシュボード API の呼び出し口。テストではネットワークへ出ないスタブを渡す。
    public typealias DashboardFetch = @Sendable (
        _ from: String, _ to: String, _ dbPath: String
    ) async -> CursorDashboardService.FetchOutcome

    private let fetchDashboard: DashboardFetch

    public init(
        stateDBURL: URL = CursorCostDriver.defaultStateDBURL,
        fetchDashboard: DashboardFetch? = nil
    ) {
        self.stateDBURL = stateDBURL
        self.fetchDashboard = fetchDashboard ?? { from, to, dbPath in
            await CursorDashboardService.fetch(from: from, to: to, dbPath: dbPath)
        }
    }

    public static var defaultStateDBURL: URL {
        // 検証・テスト用。未設定なら本番の Cursor パスを使う。
        if let override = ProcessInfo.processInfo.environment["TOKFUEL_CURSOR_DB"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }
}

// MARK: - CostDriver

extension CursorCostDriver: CostDriver {
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: stateDBURL.path)
    }

    /// Cursor 本体。サインインが切れたときはこのアプリを前面に出すだけで、Tokfuel は
    /// ログイン画面もトークン発行も持たない（他アプリの認証を代行しない）。
    public var signInBundleID: String? { "com.todesktop.230313mzl4w4u92" }

    public func snapshot(from: String, to: String) async -> CostSnapshot {
        guard isAvailable else { return .empty }
        let path = stateDBURL.path
        // ダッシュボードが取れたらそれを信じる（空でもローカルへ落とさない）。
        switch await fetchDashboard(from, to, path) {
        case .success(let remote):
            return CostSnapshot(daily: remote.daily, byModel: remote.byModel)
        case .noCredentials:
            return await localSnapshot(path: path, from: from, to: to,
                                       health: .degraded(.signedOut))
        case .unauthorized:
            return await localSnapshot(path: path, from: from, to: to,
                                       health: .degraded(.credentialsRejected))
        case .unreachable:
            return await localSnapshot(path: path, from: from, to: to,
                                       health: .degraded(.remoteUnavailable))
        }
    }

    /// `state.vscdb` のトークンスナップショットだけで作る下限推定。Cursor 3.x では
    /// `tokenCount` が残らないので、直近の期間はたいてい空になる——だから `health` を持たせる。
    private func localSnapshot(
        path: String, from: String, to: String, health: CostSnapshot.Health
    ) async -> CostSnapshot {
        let daily = await Task.detached(priority: .utility) {
            CursorUsageReader.scan(dbPath: path, from: from, to: to)
        }.value
        return CostSnapshot(daily: daily, byModel: [:], health: health)
    }

    /// 会話単位の内訳。ダッシュボード API のイベントには会話を識別する値が無い
    /// （timestamp / chargedCents / model だけ）ので、API が成功していてもここだけは
    /// ローカルの `state.vscdb` から作る。金額の桁が API 側とそろわないことがあるため、
    /// UI は合計（ヒーロー）と別物であることが分かるよう「推定」と添えて出す。
    /// ローカルが読めない・空の環境（#73、`health` が `.degraded` になる場合）では単に
    /// 空を返す —— 会話が無いことは劣化表示の担当で、$0 の行を並べる意味は無い。
    public func sessions(from: String, to: String) async -> [CostSnapshot.Session] {
        guard isAvailable else { return [] }
        let path = stateDBURL.path
        return await Task.detached(priority: .utility) {
            CursorUsageReader.scanSessions(dbPath: path, from: from, to: to)
        }.value
    }
}

/// Cursor の `state.vscdb` を読み取り専用で開く。
///
/// `state.vscdb` は WAL モード。Cursor がチェックポイントを終えると `-wal` / `-shm` が消え、
/// その状態を素の `SQLITE_OPEN_READONLY` で開くと SQLite は `-shm` を作れず、
/// **`sqlite3_open_v2` は成功したまま `sqlite3_prepare_v2` が** `SQLITE_CANTOPEN` を返す。
/// 実機ではこれで `readAccessToken` も `CursorUsageReader.scan` も静かに失敗し、Cursor の
/// コストが常に 0 円になっていた。
///
/// まず通常の読み取り専用で開き、クエリを作れないときだけ `immutable=1` で開き直す。
/// `immutable=1` は「読んでいる間ファイルは変わらない」という宣言なので常用はしない——
/// `-wal` が残っているうち（＝Cursor が書きかけ）は素の読み取り専用が成功するので、
/// この経路には来ない。
public enum CursorSQLite {
    /// 開けなければ nil（呼び出し側はいつもの「空を返す」に落ちる）。
    public static func openReadOnly(path: String) -> OpaquePointer? {
        if let db = open(dsn: path, flags: SQLITE_OPEN_READONLY) {
            if canQuery(db) { return db }
            sqlite3_close(db)
        }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let db = open(dsn: "file:\(encoded)?immutable=1",
                         flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI) {
            if canQuery(db) { return db }
            sqlite3_close(db)
        }
        return nil
    }

    private static func open(dsn: String, flags: Int32) -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dsn, &db, flags, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
        return db
    }

    /// 実際に prepare してみる。WAL の `-shm` を作れない失敗はここでしか現れない。
    private static func canQuery(_ db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        return sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master LIMIT 1", -1, &stmt, nil)
            == SQLITE_OK
    }
}

/// `state.vscdb` の生の読み取り。SQLite3 の C API を直接叩く（新規パッケージ依存を増やさない
/// ため——システムの libsqlite3 のみを使う）。
public enum CursorUsageReader {
    /// Cursor の会話 1 件。`CostSnapshot.Session` と同じ形なので、driver 側は詰め替えずに返す。
    public typealias CursorSession = CostSnapshot.Session

    /// 会話名が取れない composer の表示名。
    public static let untitledSessionTitle = "無題の会話"

    /// 1 回の走査で得られる日別と会話別。同じ bubble 行から両方を作るので、
    /// 呼び出し口が 2 つあっても SQLite を 2 度開かない。
    public struct ScanResult: Sendable {
        public let daily: [String: Double]
        public let sessions: [CursorSession]

        public static let empty = ScanResult(daily: [:], sessions: [])
    }

    /// [from, to] 区間（両端含む、"YYYY-MM-DD"、ローカル日付）で日別コストを集計する。
    /// 失敗はすべて空辞書に落ちる（呼び出し側でエラー表示が必要な処理ではない）。
    public static func scan(dbPath: String, from: String, to: String) -> [String: Double] {
        scanAll(dbPath: dbPath, from: from, to: to).daily
    }

    /// [from, to] 区間の会話（composer）単位の内訳をコスト降順で返す。
    /// コストが 0 のままの会話は落とす —— Cursor 3.x では `tokenCount` が残らず
    /// ローカル走査が空になることがあり（#73）、そこで「$0 の会話」を並べても意味が無い。
    public static func scanSessions(dbPath: String, from: String, to: String) -> [CursorSession] {
        scanAll(dbPath: dbPath, from: from, to: to).sessions
    }

    /// bubble 行の 1 パス走査。日別と会話別を同時に積む。
    /// 開き方は `CursorSQLite.openReadOnly` に任せる（WAL のチェックポイント後に
    /// `sqlite3_prepare_v2` が静かに落ちる問題は、そこで `immutable=1` へ落として回避する）。
    public static func scanAll(dbPath: String, from: String, to: String) -> ScanResult {
        guard let db = CursorSQLite.openReadOnly(path: dbPath) else { return .empty }
        defer { sqlite3_close(db) }

        let composers = loadComposers(db: db)

        var stmt: OpaquePointer?
        let sql = "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return .empty
        }
        defer { sqlite3_finalize(stmt) }

        var totals: [String: Double] = [:]
        var accumulators: [String: SessionAccumulator] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let keyRaw = sqlite3_column_text(stmt, 0),
                  let valueRaw = sqlite3_column_text(stmt, 1) else { continue }
            let key = String(cString: keyRaw)
            let composer = composerId(fromBubbleKey: key)
            guard let cost = costEntry(
                fromBubbleJSON: String(cString: valueRaw),
                composerModelID: composer.flatMap { composers[$0]?.model }
            ) else { continue }
            guard cost.date >= from, cost.date <= to else { continue }
            totals[cost.date, default: 0] += cost.amount
            guard let composer else { continue }
            var accumulator = accumulators[composer] ?? SessionAccumulator()
            accumulator.add(cost)
            accumulators[composer] = accumulator
        }

        let sessions = accumulators.compactMap { id, accumulator -> CursorSession? in
            guard accumulator.cost > 0 else { return nil }
            return CursorSession(
                id: id,
                title: composers[id]?.title ?? untitledSessionTitle,
                cost: accumulator.cost,
                messages: accumulator.messages,
                lastUsed: accumulator.lastUsed)
        }
        // コストが並んだときは ID 順にして、同じ DB からは常に同じ並びが出るようにする。
        .sorted { $0.cost == $1.cost ? $0.id < $1.id : $0.cost > $1.cost }
        return ScanResult(daily: totals, sessions: sessions)
    }

    /// 1 会話ぶんの積み上げ。走査中だけ使う可変の入れ物。
    private struct SessionAccumulator {
        var cost: Double = 0
        var messages: Int = 0
        var lastUsed: String = ""

        mutating func add(_ entry: DatedCost) {
            cost += entry.amount
            messages += 1
            if entry.date > lastUsed { lastUsed = entry.date }
        }
    }

    public struct DatedCost {
        let date: String
        let amount: Double
    }

    /// 1 bubble ぶんの JSON から (日付, 金額) を取り出す。トークンスナップショットや作成日時が
    /// 読めない行は nil を返す（呼び出し側で無視される = 下限推定に留まる）。
    ///
    /// - Parameter composerModelID: 同 composer の `modelConfig.modelName`。bubble 側に
    ///   モデルが無いときに使う（実データの大半がこの経路）。
    public static func costEntry(fromBubbleJSON json: String, composerModelID: String? = nil) -> DatedCost? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let date = dayString(fromCreatedAt: object["createdAt"]) else { return nil }

        let (input, output) = tokenCounts(from: object)
        guard input > 0 || output > 0 else { return nil }

        let modelID = modelID(from: object) ?? composerModelID
        let amount = CursorPricing.cost(modelID: modelID, inputTokens: input, outputTokens: output)
        return DatedCost(date: date, amount: amount)
    }

    /// `bubbleId:<composerId>:<bubbleId>` から composerId を抜く。UUID に `:` は無いので
    /// 単純 split で足りる。形が違えば nil。
    public static func composerId(fromBubbleKey key: String) -> String? {
        let parts = key.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "bubbleId", !parts[1].isEmpty else { return nil }
        return String(parts[1])
    }

    /// `composerData:*` 行から先読みした 1 会話ぶんのメタ情報。
    public struct ComposerInfo {
        /// `modelConfig.modelName`。bubble 側にモデルが無いときの価格付けに使う。
        let model: String?
        /// 会話名。無題の会話では nil。
        let title: String?
    }

    /// `composerData:*` 行から `composerId → (modelName, 会話名)` を先読みする。
    private static func loadComposers(db: OpaquePointer) -> [String: ComposerInfo] {
        var stmt: OpaquePointer?
        let sql = "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var composers: [String: ComposerInfo] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let keyRaw = sqlite3_column_text(stmt, 0),
                  let valueRaw = sqlite3_column_text(stmt, 1) else { continue }
            let key = String(cString: keyRaw)
            guard key.hasPrefix("composerData:") else { continue }
            let composerId = String(key.dropFirst("composerData:".count))
            guard !composerId.isEmpty,
                  let data = String(cString: valueRaw).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let info = ComposerInfo(model: modelID(fromComposer: object),
                                    title: title(fromComposer: object))
            guard info.model != nil || info.title != nil else { continue }
            composers[composerId] = info
        }
        return composers
    }

    /// 会話名。Cursor は `name` に持ち、古い形では最初の発話 `text` しか無いことがある。
    /// 1 行に畳んで長さを切る（ポップオーバーの 1 行に収まればよく、全文は要らない）。
    public static func title(fromComposer object: [String: Any]) -> String? {
        guard let raw = stringValue(object["name"]) ?? stringValue(object["text"]) else {
            return nil
        }
        let flattened = raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !flattened.isEmpty else { return nil }
        return flattened.count > 80 ? String(flattened.prefix(80)) + "…" : flattened
    }

    private static func tokenCounts(from object: [String: Any]) -> (Int, Int) {
        // 実データ: tokenCount.inputTokens / tokenCount.outputTokens
        if let nested = object["tokenCount"] as? [String: Any] {
            let input = intValue(nested["inputTokens"]) ?? 0
            let output = intValue(nested["outputTokens"]) ?? 0
            if input > 0 || output > 0 {
                return (input, output)
            }
        }
        // 旧想定・テスト互換のトップレベル
        return (intValue(object["inputTokens"]) ?? 0, intValue(object["outputTokens"]) ?? 0)
    }

    private static func modelID(from object: [String: Any]) -> String? {
        if let info = object["modelInfo"] as? [String: Any],
           let name = stringValue(info["modelName"]) ?? stringValue(info["model"]) {
            return name
        }
        return stringValue(object["modelName"])
            ?? stringValue(object["model"])
            ?? stringValue(object["modelId"])
    }

    private static func modelID(fromComposer object: [String: Any]) -> String? {
        if let config = object["modelConfig"] as? [String: Any],
           let name = stringValue(config["modelName"]) ?? stringValue(config["model"]) {
            return name
        }
        return modelID(from: object)
    }

    /// ISO-8601 文字列、または epoch ミリ秒（数値 / 数字だけの文字列）→ ローカル "YYYY-MM-DD"。
    private static func dayString(fromCreatedAt value: Any?) -> String? {
        if let date = date(fromCreatedAt: value) {
            return LocalDay.string(from: date)
        }
        return nil
    }

    private static func date(fromCreatedAt value: Any?) -> Date? {
        switch value {
        case let n as NSNumber:
            return date(fromEpochMillis: n.doubleValue)
        case let s as String:
            if let millis = Double(s), millis > 0, !s.contains("-"), !s.contains("T") {
                return date(fromEpochMillis: millis)
            }
            return isoDateFormatter.date(from: s) ?? isoDateFormatterNoFraction.date(from: s)
        default:
            return nil
        }
    }

    private static func date(fromEpochMillis millis: Double) -> Date? {
        guard millis > 0 else { return nil }
        // 秒で渡ってきた場合（1e12 未満）も一応受け付ける
        let seconds = millis > 1_000_000_000_000 ? millis / 1000 : millis
        return Date(timeIntervalSince1970: seconds)
    }

    // ISO8601DateFormatter はスレッド安全（Apple ドキュメント）だが Sendable ではない。
    // UsageEventLog と同じ nonisolated(unsafe) で静的に持ち回す。
    nonisolated(unsafe) private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let isoDateFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        (value as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
