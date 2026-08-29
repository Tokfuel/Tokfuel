import Foundation
import SQLite3
import TokfuelCore

/// ダッシュボード API が無いとローカル DB の tokenCount はほぼ 0 のままなので、今日の使用が常に $0 になる。
/// フォールバック時は health を degraded にし、「使っていない」と「取れていない」を UI が書き分けられるようにする。
public struct CursorCostDriver {
    public let id = "cursor"
    public let displayName = "Cursor"
    public let stateDBURL: URL

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
        if let override = ProcessInfo.processInfo.environment["TOKFUEL_CURSOR_DB"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }
}


extension CursorCostDriver: CostDriver {
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: stateDBURL.path)
    }

    /// ログイン画面もトークン発行も持たない（他アプリの認証を代行しない）。
    public var signInBundleID: String? { "com.todesktop.230313mzl4w4u92" }

    public func snapshot(from: String, to: String) async -> CostSnapshot {
        guard isAvailable else { return .empty }
        let path = stateDBURL.path
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

    /// `tokenCount` が残らないので、直近の期間はたいてい空になる——だから `health` を持たせる。
    private func localSnapshot(
        path: String, from: String, to: String, health: CostSnapshot.Health
    ) async -> CostSnapshot {
        let daily = await Task.detached(priority: .utility) {
            CursorUsageReader.scan(dbPath: path, from: from, to: to)
        }.value
        return CostSnapshot(daily: daily, byModel: [:], health: health)
    }

    /// 会話 API には会話 ID が無いので、内訳だけは state.vscdb から作る。桁が API と揃わない行は並べない。
    public func sessions(from: String, to: String) async -> [CostSnapshot.Session] {
        guard isAvailable else { return [] }
        let path = stateDBURL.path
        return await Task.detached(priority: .utility) {
            CursorUsageReader.scanSessions(dbPath: path, from: from, to: to)
        }.value
    }
}

/// WAL がある間は readonly で開ける。immutable=1 は常用しない（読み取り専用の宣言が強すぎる）。
public enum CursorSQLite {
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

    private static func canQuery(_ db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        return sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master LIMIT 1", -1, &stmt, nil)
            == SQLITE_OK
    }
}

public enum CursorUsageReader {
    public typealias CursorSession = CostSnapshot.Session

    public static let untitledSessionTitle = "無題の会話"

    public struct ScanResult: Sendable {
        public let daily: [String: Double]
        public let sessions: [CursorSession]

        public static let empty = ScanResult(daily: [:], sessions: [])
    }

    public static func scan(dbPath: String, from: String, to: String) -> [String: Double] {
        scanAll(dbPath: dbPath, from: from, to: to).daily
    }

    /// Cursor 3.x では tokenCount が残らずコスト 0 の会話が多いので、並べない。
    public static func scanSessions(dbPath: String, from: String, to: String) -> [CursorSession] {
        scanAll(dbPath: dbPath, from: from, to: to).sessions
    }

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
        .sorted { $0.cost == $1.cost ? $0.id < $1.id : $0.cost > $1.cost }
        return ScanResult(daily: totals, sessions: sessions)
    }

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

    public static func composerId(fromBubbleKey key: String) -> String? {
        let parts = key.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "bubbleId", !parts[1].isEmpty else { return nil }
        return String(parts[1])
    }

    public struct ComposerInfo {
        let model: String?
        let title: String?
    }

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
        if let nested = object["tokenCount"] as? [String: Any] {
            let input = intValue(nested["inputTokens"]) ?? 0
            let output = intValue(nested["outputTokens"]) ?? 0
            if input > 0 || output > 0 {
                return (input, output)
            }
        }
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
        let seconds = millis > 1_000_000_000_000 ? millis / 1000 : millis
        return Date(timeIntervalSince1970: seconds)
    }

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
