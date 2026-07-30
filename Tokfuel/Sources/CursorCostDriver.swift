import Foundation
import SQLite3

/// Cursor のローカル使用量を二次コスト源として読む CostDriver。
///
/// **既知の限界（実データで検証できていない）**: Cursor は `state.vscdb`（SQLite）の
/// `cursorDiskKV` テーブルに `bubbleId:<composerId>:<bubbleId>` という鍵でメッセージごとの
/// JSON を持ち、その中に `{inputTokens, outputTokens}` のトークンスナップショットが入って
/// いることがある——というのはコミュニティツール（tokcat, cursor-history 等）の観測に基づく
/// リバースエンジニアリングで、Cursor 公式のスキーマ保証は無い。このメソッド実装は
/// 「壊れていても壊れて見えない」ことを最優先にしている: 想定した鍵が無い・型が違う行は
/// 静かにスキップし、テーブルやカラム自体が無ければ丸ごと空を返す。DB を開けない・
/// クエリが失敗する等、あらゆる失敗が「Cursor のデータは無かった」と同じ扱いになる
/// （これはオマケのデータであり、Cost タブの本体である retok とは失敗時の扱いを変える）。
///
/// 合算されるのは「トークンスナップショットが取れたメッセージ」だけなので、常に実際の
/// 支出の下限にしかならない——UI 側でも「推定」であることを明示する。
struct CursorCostDriver {
    let id = "cursor"
    let displayName = "Cursor"
    let stateDBURL: URL

    init(stateDBURL: URL = CursorCostDriver.defaultStateDBURL) {
        self.stateDBURL = stateDBURL
    }

    static var defaultStateDBURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
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

        var stmt: OpaquePointer?
        let sql = "SELECT value FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var totals: [String: Double] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let raw = sqlite3_column_text(stmt, 0) else { continue }
            guard let cost = costEntry(fromBubbleJSON: String(cString: raw)) else { continue }
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
    static func costEntry(fromBubbleJSON json: String) -> DatedCost? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let date = dayString(fromCreatedAt: object["createdAt"]) else { return nil }

        let input = intValue(object["inputTokens"]) ?? 0
        let output = intValue(object["outputTokens"]) ?? 0
        guard input > 0 || output > 0 else { return nil }

        // モデル名の置き場所もスキーマ未確定。よくありそうな鍵をいくつか試し、
        // どれも無ければ CursorPricing 側で「不明なモデルは 0」に落ちる。
        let modelID = stringValue(object["model"]) ?? stringValue(object["modelId"])
            ?? stringValue(object["unifiedMode"])
        let amount = CursorPricing.cost(modelID: modelID, inputTokens: input, outputTokens: output)
        return DatedCost(date: date, amount: amount)
    }

    /// エポックミリ秒（Cursor の createdAt の想定形式）→ ローカル日付の "YYYY-MM-DD"。
    /// Claude 側の集計キーと同じ書式にそろえるため、UsageStore.dateString をそのまま使う。
    private static func dayString(fromCreatedAt value: Any?) -> String? {
        guard let millis = doubleValue(value), millis > 0 else { return nil }
        return UsageStore.dateString(Date(timeIntervalSince1970: millis / 1000))
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

    private static func stringValue(_ value: Any?) -> String? {
        (value as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
