import Foundation
import SQLite3

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
struct CursorCostDriver {
    let id = "cursor"
    let displayName = "Cursor"
    let stateDBURL: URL

    init(stateDBURL: URL = CursorCostDriver.defaultStateDBURL) {
        self.stateDBURL = stateDBURL
    }

    static var defaultStateDBURL: URL {
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
    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: stateDBURL.path)
    }

    func dailyCosts(from: String, to: String) async -> [String: Double] {
        guard isAvailable else { return [:] }
        let path = stateDBURL.path
        // ダッシュボードが取れたらそれを信じる（空でもローカルへ落とさない）。
        if let remote = await CursorDashboardService.dailyCosts(from: from, to: to, dbPath: path) {
            return remote
        }
        return await Task.detached(priority: .utility) {
            CursorUsageReader.scan(dbPath: path, from: from, to: to)
        }.value
    }
}

/// `state.vscdb` の生の読み取り。SQLite3 の C API を直接叩く（新規パッケージ依存を増やさない
/// ため——システムの libsqlite3 のみを使う）。
enum CursorUsageReader {
    /// [from, to] 区間（両端含む、"YYYY-MM-DD"、ローカル日付）で日別コストを集計する。
    /// 失敗はすべて空辞書に落ちる（呼び出し側でエラー表示が必要な処理ではない）。
    static func scan(dbPath: String, from: String, to: String) -> [String: Double] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }

        let composerModels = loadComposerModels(db: db)

        var stmt: OpaquePointer?
        let sql = "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var totals: [String: Double] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let keyRaw = sqlite3_column_text(stmt, 0),
                  let valueRaw = sqlite3_column_text(stmt, 1) else { continue }
            let key = String(cString: keyRaw)
            let composerModel = composerId(fromBubbleKey: key).flatMap { composerModels[$0] }
            guard let cost = costEntry(
                fromBubbleJSON: String(cString: valueRaw),
                composerModelID: composerModel
            ) else { continue }
            guard cost.date >= from, cost.date <= to else { continue }
            totals[cost.date, default: 0] += cost.amount
        }
        return totals
    }

    struct DatedCost {
        let date: String
        let amount: Double
    }

    /// 1 bubble ぶんの JSON から (日付, 金額) を取り出す。トークンスナップショットや作成日時が
    /// 読めない行は nil を返す（呼び出し側で無視される = 下限推定に留まる）。
    ///
    /// - Parameter composerModelID: 同 composer の `modelConfig.modelName`。bubble 側に
    ///   モデルが無いときに使う（実データの大半がこの経路）。
    static func costEntry(fromBubbleJSON json: String, composerModelID: String? = nil) -> DatedCost? {
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
    static func composerId(fromBubbleKey key: String) -> String? {
        let parts = key.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "bubbleId", !parts[1].isEmpty else { return nil }
        return String(parts[1])
    }

    /// `composerData:*` 行から `composerId → modelName` を先読みする。
    private static func loadComposerModels(db: OpaquePointer) -> [String: String] {
        var stmt: OpaquePointer?
        let sql = "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var models: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let keyRaw = sqlite3_column_text(stmt, 0),
                  let valueRaw = sqlite3_column_text(stmt, 1) else { continue }
            let key = String(cString: keyRaw)
            guard key.hasPrefix("composerData:") else { continue }
            let composerId = String(key.dropFirst("composerData:".count))
            guard !composerId.isEmpty,
                  let data = String(cString: valueRaw).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let model = modelID(fromComposer: object)
            else { continue }
            models[composerId] = model
        }
        return models
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
            return UsageStore.dateString(date)
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
