import SQLite3
import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
@testable import Tokfuel

private func localDateString(epochMillis: Double) -> String {
    UsageStore.dateString(Date(timeIntervalSince1970: epochMillis / 1000))
}

private func localDateString(iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = f.date(from: iso)!
    return UsageStore.dateString(date)
}

/// 自分が足したキーだけ剥がす（差分マージなので他の並行テストのキーは壊さない）。
/// キーは呼び出し側で重ならないようにする——同じキーを共有すると、片方の後始末が
/// もう片方の実行中にキーを剥がしてしまう。
private func withPricing(_ rates: [(key: String, input: Double, output: Double)], _ body: () -> Void) {
    let cached = rates.map {
        CursorPricingService.CachedRate(key: $0.key, input: $0.input, output: $0.output)
    }
    CursorPricingService.setCachedRatesForTesting(cached)
    defer { CursorPricingService.removeCachedRatesForTesting(keys: rates.map(\.key)) }
    body()
}

/// costEntry の金額は CursorPricing 経由でキャッシュを見るので、
/// 金額を検証するテストはここでキャッシュを差し込んでから読む。
struct CursorCostDriverParsingTests {
    private static let epoch: Double = 1785312000000
    private static let iso = "2025-10-02T06:19:31.163Z"

    @Test func 実データ形_tokenCountとISOとmodelInfoでコストを返す() {
        withPricing([("utest1-claude-4.5-sonnet", 3.0, 15.0)]) {
            let json = """
            {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 500000}, "modelInfo": {"modelName": "utest1-claude-4.5-sonnet-thinking"}}
            """
            let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
            #expect(entry?.date == localDateString(iso: Self.iso))
            #expect(entry?.amount == 3.0 + 7.5)   // 1M*$3 + 0.5M*$15
        }
    }

    @Test func bubbleにモデルが無くてもcomposerModelIDで価格化できる() {
        withPricing([("utest2-claude-4-sonnet", 3.0, 15.0)]) {
            let json = """
            {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
            """
            let entry = CursorUsageReader.costEntry(
                fromBubbleJSON: json,
                composerModelID: "utest2-claude-4-sonnet"
            )
            #expect(entry?.date == localDateString(iso: Self.iso))
            #expect(entry?.amount == 3.0)
        }
    }

    @Test func モデル不明ならコストはゼロだが日付は取れる() {
        withPricing([("utest3-claude-4-sonnet", 3.0, 15.0)]) {
            let json = """
            {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 100, "outputTokens": 50}, "modelInfo": {"modelName": "utest3-some-future-model"}}
            """
            let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
            #expect(entry?.date == localDateString(iso: Self.iso))
            #expect(entry?.amount == 0)
        }
    }

    @Test func 未登録のモデルはコストはゼロ() {
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 500000}, "modelInfo": {"modelName": "utest4-never-cached-\(UUID().uuidString)"}}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.date == localDateString(iso: Self.iso))
        #expect(entry?.amount == 0)
    }

    @Test func createdAtが無ければnil() {
        let json = """
        {"tokenCount": {"inputTokens": 100, "outputTokens": 50}, "modelInfo": {"modelName": "claude-sonnet-4-5"}}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
    }

    @Test func トークンが両方ゼロならnil() {
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 0, "outputTokens": 0}, "modelInfo": {"modelName": "claude-sonnet-4-5"}}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
    }

    @Test func epochミリ秒のcreatedAtも受け付ける() {
        withPricing([("utest5-claude-sonnet-4-5", 3.0, 15.0)]) {
            let json = """
            {"createdAt": \(Self.epoch), "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "utest5-claude-sonnet-4-5"}}
            """
            let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
            #expect(entry?.date == localDateString(epochMillis: Self.epoch))
            #expect(entry?.amount == 3.0)
        }
    }

    @Test func 壊れたJSONはnil() {
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: "{not json") == nil)
    }

    @Test func 想定外の型でもクラッシュしない() {
        let json = """
        {"createdAt": "not-a-date", "tokenCount": {"inputTokens": "lots"}, "modelInfo": {"modelName": 42}}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
    }

    @Test func unifiedModeはモデル名として使わない() {
        // stringValue() の時点で弾かれ、そもそも価格表を引く対象にならない——キャッシュは不要。
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "unifiedMode": 2}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.amount == 0)
    }

    @Test func composerIdをbubbleキーから抜ける() {
        #expect(
            CursorUsageReader.composerId(
                fromBubbleKey: "bubbleId:0041d255-daf2-4e88-8bc0-0e39dafe297d:0919d59a-f84a-41de-a6eb-b0acaef894e9"
            ) == "0041d255-daf2-4e88-8bc0-0e39dafe297d"
        )
        #expect(CursorUsageReader.composerId(fromBubbleKey: "composerData:x") == nil)
    }
}

private func makeCursorFixtureDB(rows: [(key: String, value: String)]) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cursor-fixture-\(UUID().uuidString).sqlite")
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(sqlite3_exec(db, "CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value TEXT)",
                         nil, nil, nil) == SQLITE_OK)
    for row in rows {
        var stmt: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                                   -1, &stmt, nil) == SQLITE_OK)
        sqlite3_bind_text(stmt, 1, row.key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, row.value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        #expect(sqlite3_step(stmt) == SQLITE_DONE)
        sqlite3_finalize(stmt)
    }
    return url
}

struct CursorUsageReaderScanTests {
    private func makeFixtureDB(rows: [(key: String, value: String)]) -> URL {
        makeCursorFixtureDB(rows: rows)
    }

    private static let iso = "2025-10-02T06:19:31.163Z"

    @Test func bubbleId行だけ拾ってcomposerモデルで日別に合算する() {
        let db = makeFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "utest6-claude-4-sonnet"}}
             """),
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
             """),
            ("bubbleId:c1:b2", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
             """),
            ("composerData:other", "{\"modelConfig\": {\"modelName\": \"utest6-gpt-5\"}}"),
            ("bubbleId:c1:broken", "{not json")
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest6-claude-4-sonnet", 3.0, 15.0), ("utest6-gpt-5", 1.25, 10.0)]) {
            let day = localDateString(iso: Self.iso)
            let month = String(day.prefix(7))
            let totals = CursorUsageReader.scan(dbPath: db.path, from: "\(month)-01", to: "\(month)-31")
            #expect(totals[day] == 6.0)   // 1M + 1M input * $3/MTok
            #expect(totals.count == 1)
        }
    }

    @Test func bubbleのmodelInfoがcomposerより優先される() {
        let db = makeFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "utest7-gpt-5"}}
             """),
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "utest7-claude-4-sonnet"}}
             """)
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest7-claude-4-sonnet", 3.0, 15.0), ("utest7-gpt-5", 1.25, 10.0)]) {
            let day = localDateString(iso: Self.iso)
            let totals = CursorUsageReader.scan(dbPath: db.path, from: day, to: day)
            #expect(totals[day] == 3.0)
        }
    }

    @Test func 期間の外は集計に含めない() {
        let db = makeFixtureDB(rows: [
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "utest8-claude-sonnet-4-5"}}
             """)
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        let totals = CursorUsageReader.scan(dbPath: db.path, from: "2020-01-01", to: "2020-01-31")
        #expect(totals.isEmpty)
    }

    @Test func テーブルが無いDBでも空を返す() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-empty-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        sqlite3_close(db)
        defer { try? FileManager.default.removeItem(at: url) }

        let totals = CursorUsageReader.scan(dbPath: url.path, from: "2026-01-01", to: "2026-12-31")
        #expect(totals.isEmpty)
    }

    @Test func 存在しないパスでも空を返す() {
        let totals = CursorUsageReader.scan(dbPath: "/nonexistent/state.vscdb",
                                            from: "2026-01-01", to: "2026-12-31")
        #expect(totals.isEmpty)
    }
}

/// composerData / bubbleId のフィクスチャから会話単位の内訳を起こせるか。
struct CursorUsageReaderSessionTests {
    private static let iso = "2025-10-02T06:19:31.163Z"
    private static let isoNextDay = "2025-10-03T09:00:00.000Z"

    private func bubble(_ iso: String, input: Int) -> String {
        """
        {"createdAt": "\(iso)", "tokenCount": {"inputTokens": \(input), "outputTokens": 0}}
        """
    }

    @Test func composerIdでまとめて会話名と最終利用日を取る() {
        let db = makeCursorFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "utest20-claude-4-sonnet"}, "name": "レイアウト崩れを直す"}
             """),
            ("bubbleId:c1:b1", bubble(Self.iso, input: 1_000_000)),
            ("bubbleId:c1:b2", bubble(Self.isoNextDay, input: 1_000_000))
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest20-claude-4-sonnet", 3.0, 15.0)]) {
            let sessions = CursorUsageReader.scanSessions(
                dbPath: db.path, from: "2025-01-01", to: "2026-12-31")
            #expect(sessions.count == 1)
            #expect(sessions.first?.id == "c1")
            #expect(sessions.first?.title == "レイアウト崩れを直す")
            #expect(sessions.first?.cost == 6.0)
            #expect(sessions.first?.messages == 2)
            #expect(sessions.first?.lastUsed == localDateString(iso: Self.isoNextDay))
        }
    }

    @Test func 会話名が無ければ無題の会話になる() {
        let db = makeCursorFixtureDB(rows: [
            ("composerData:c1", "{\"modelConfig\": {\"modelName\": \"utest21-claude-4-sonnet\"}}"),
            ("bubbleId:c1:b1", bubble(Self.iso, input: 1_000_000))
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest21-claude-4-sonnet", 3.0, 15.0)]) {
            let sessions = CursorUsageReader.scanSessions(
                dbPath: db.path, from: "2025-01-01", to: "2026-12-31")
            #expect(sessions.first?.title == CursorUsageReader.untitledSessionTitle)
        }
    }

    @Test func コスト降順に並べる() {
        let db = makeCursorFixtureDB(rows: [
            ("composerData:small", """
             {"modelConfig": {"modelName": "utest22-claude-4-sonnet"}, "name": "小さい会話"}
             """),
            ("composerData:big", """
             {"modelConfig": {"modelName": "utest22-claude-4-sonnet"}, "name": "大きい会話"}
             """),
            ("bubbleId:small:b1", bubble(Self.iso, input: 1_000_000)),
            ("bubbleId:big:b1", bubble(Self.iso, input: 5_000_000))
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest22-claude-4-sonnet", 3.0, 15.0)]) {
            let sessions = CursorUsageReader.scanSessions(
                dbPath: db.path, from: "2025-01-01", to: "2026-12-31")
            #expect(sessions.map(\.title) == ["大きい会話", "小さい会話"])
        }
    }

    /// 価格を引けないモデルが $0 になる。$0 の会話は行にしない。
    @Test func 価格を引けない会話は行にしない() {
        let db = makeCursorFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "utest23-never-cached-model"}, "name": "値付け不能"}
             """),
            ("bubbleId:c1:b1", bubble(Self.iso, input: 1_000_000))
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        #expect(CursorUsageReader.scanSessions(
            dbPath: db.path, from: "2025-01-01", to: "2026-12-31").isEmpty)
    }

    @Test func 期間の外の会話は返さない() {
        let db = makeCursorFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "utest24-claude-4-sonnet"}, "name": "去年の会話"}
             """),
            ("bubbleId:c1:b1", bubble(Self.iso, input: 1_000_000))
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        withPricing([("utest24-claude-4-sonnet", 3.0, 15.0)]) {
            #expect(CursorUsageReader.scanSessions(
                dbPath: db.path, from: "2020-01-01", to: "2020-12-31").isEmpty)
        }
    }

    @Test func 走査できないDBでも空を返す() {
        #expect(CursorUsageReader.scanSessions(
            dbPath: "/nonexistent/state.vscdb", from: "2026-01-01", to: "2026-12-31").isEmpty)
    }

    @Test func 会話名は1行に畳んで長さを切る() {
        let long = String(repeating: "あ", count: 200)
        #expect(CursorUsageReader.title(fromComposer: ["name": " 上の行 \n 下の行 "])
                == "上の行 下の行")
        #expect(CursorUsageReader.title(fromComposer: ["text": long])?.count == 81)
        #expect(CursorUsageReader.title(fromComposer: ["name": "  \n "]) == nil)
        #expect(CursorUsageReader.title(fromComposer: [:]) == nil)
    }
}

/// CostDriver 準拠としての isAvailable / dailyCosts の zero-setup 劣化を確認する。
struct CursorCostDriverTests {
    @Test func ファイルが無ければ利用不可で空を返す() async {
        let driver = CursorCostDriver(stateDBURL: URL(fileURLWithPath: "/nonexistent/state.vscdb"))
        #expect(driver.isAvailable == false)
        let costs = await driver.dailyCosts(from: "2026-01-01", to: "2026-12-31")
        #expect(costs.isEmpty)
        let sessions = await driver.sessions(from: "2026-01-01", to: "2026-12-31")
        #expect(sessions.isEmpty)
    }

    @Test func セッションを持たないdriverは既定で空() async {
        let sessions = await CodexCostDriver().sessions(from: "2026-01-01", to: "2026-12-31")
        #expect(sessions.isEmpty)
    }

    @Test func ファイルがあれば利用可能() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-avail-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let driver = CursorCostDriver(stateDBURL: url)
        #expect(driver.isAvailable)
    }

}

/// `SQLITE_OPEN_READONLY` は WAL 残存 DB を開けず、失敗は `prepare` で起きるので、
/// 「テーブルが無い DB」と同じ静かな空返しに紛れる。ここが壊れると Cursor は常に 0 円になる。
struct CursorSQLiteWALTests {
    /// この 3 点が揃ったときだけ素の読み取り専用が `SQLITE_CANTOPEN` になるので、
    private func makeCheckpointedWALDB(extraSQL: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-wal-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(db, extraSQL, nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)
        for suffix in ["-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
        var plain: OpaquePointer?
        #expect(sqlite3_open_v2(url.path, &plain, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        var stmt: OpaquePointer?
        let prepared = sqlite3_prepare_v2(plain, "SELECT 1 FROM sqlite_master LIMIT 1",
                                          -1, &stmt, nil)
        sqlite3_finalize(stmt)
        sqlite3_close(plain)
        #expect(prepared == SQLITE_CANTOPEN)
        return url
    }

    @Test func チェックポイント済みWALでもトークンを読める() {
        let url = makeCheckpointedWALDB(extraSQL: """
        CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT);
        INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', 'wal-token');
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(CursorDashboardService.readAccessToken(dbPath: url.path) == "wal-token")
    }

    @Test func チェックポイント済みWALでもbubbleを走査できる() {
        withPricing([("utest-wal-claude-4-sonnet", 3.0, 15.0)]) {
            let json = """
            {"createdAt": "2025-10-02T06:19:31.163Z", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "utest-wal-claude-4-sonnet"}}
            """
            let url = makeCheckpointedWALDB(extraSQL: """
            CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value TEXT);
            INSERT INTO cursorDiskKV VALUES ('bubbleId:c1:b1', '\(json)');
            """)
            defer { try? FileManager.default.removeItem(at: url) }

            let daily = CursorUsageReader.scan(dbPath: url.path,
                                               from: "2025-01-01", to: "2025-12-31")
            #expect(daily.values.reduce(0, +) == 3.0)
        }
    }

    @Test func 開けないパスでも従来どおり空を返す() {
        #expect(CursorSQLite.openReadOnly(path: "/nonexistent/state.vscdb") == nil)
    }
}

struct CursorCostDriverHealthTests {
    private func makeEmptyDB() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-health-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    @Test func API成功ならhealthはok() async {
        let url = makeEmptyDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let driver = CursorCostDriver(stateDBURL: url) { _, _, _ in
            .success(.init(daily: ["2026-07-30": 1.5], byModel: ["gpt-5": 1.5]))
        }

        let snapshot = await driver.snapshot(from: "2026-07-01", to: "2026-07-31")
        #expect(snapshot.health == .ok)
        #expect(snapshot.daily == ["2026-07-30": 1.5])
    }

    @Test func 認証情報が無ければsignedOutで劣化を伝える() async {
        let url = makeEmptyDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let driver = CursorCostDriver(stateDBURL: url) { _, _, _ in .noCredentials }

        let snapshot = await driver.snapshot(from: "2026-07-01", to: "2026-07-31")
        #expect(snapshot.health == .degraded(.signedOut))
        // 金額は 0 に落ちる（合算は壊さない）。区別は health だけが担う。
        #expect(snapshot.daily.isEmpty)
    }

    @Test func API到達不能ならremoteUnavailableで劣化を伝える() async {
        let url = makeEmptyDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let driver = CursorCostDriver(stateDBURL: url) { _, _, _ in .unreachable }

        let snapshot = await driver.snapshot(from: "2026-07-01", to: "2026-07-31")
        #expect(snapshot.health == .degraded(.remoteUnavailable))
    }

    @Test func 認証拒否はcredentialsRejectedで伝える() async {
        // サインインし直せば直る種類なので、到達不能とは区別する。
        let url = makeEmptyDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let driver = CursorCostDriver(stateDBURL: url) { _, _, _ in .unauthorized }

        let snapshot = await driver.snapshot(from: "2026-07-01", to: "2026-07-31")
        #expect(snapshot.health == .degraded(.credentialsRejected))
        #expect(CostSnapshot.Degradation.credentialsRejected.isRecoverableBySignIn)
        #expect(CostSnapshot.Degradation.remoteUnavailable.isRecoverableBySignIn == false)
    }

    @Test func 未インストールなら劣化扱いにしない() async {
        // Cursor を使っていない Mac に注意書きを出さない（zero-setup の劣化と同じ形）。
        let driver = CursorCostDriver(stateDBURL: URL(fileURLWithPath: "/nonexistent/state.vscdb")) {
            _, _, _ in .unreachable
        }
        let snapshot = await driver.snapshot(from: "2026-07-01", to: "2026-07-31")
        #expect(snapshot.health == .ok)
    }
}
