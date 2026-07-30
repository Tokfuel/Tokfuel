import Foundation
import SQLite3
import Testing
@testable import Tokfuel

/// テスト用のエポックミリ秒 → "YYYY-MM-DD"。実装側と同じ UsageStore.dateString を使う。
private func localDateString(epochMillis: Double) -> String {
    UsageStore.dateString(Date(timeIntervalSince1970: epochMillis / 1000))
}

private func localDateString(iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = f.date(from: iso)!
    return UsageStore.dateString(date)
}

/// 実機の Cursor `state.vscdb` で確認したスキーマ形に対するパースを検証する。
struct CursorCostDriverParsingTests {
    private static let epoch: Double = 1785312000000
    private static let iso = "2025-10-02T06:19:31.163Z"

    @Test func 実データ形_tokenCountとISOとmodelInfoでコストを返す() {
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 500000}, "modelInfo": {"modelName": "claude-4.5-sonnet-thinking"}}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.date == localDateString(iso: Self.iso))
        #expect(entry?.amount == 3.0 + 7.5)   // 1M*$3 + 0.5M*$15
    }

    @Test func bubbleにモデルが無くてもcomposerModelIDで価格化できる() {
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
        """
        let entry = CursorUsageReader.costEntry(
            fromBubbleJSON: json,
            composerModelID: "claude-4-sonnet"
        )
        #expect(entry?.date == localDateString(iso: Self.iso))
        #expect(entry?.amount == 3.0)
    }

    @Test func モデル不明ならコストはゼロだが日付は取れる() {
        let json = """
        {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 100, "outputTokens": 50}, "modelInfo": {"modelName": "some-future-model"}}
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
        let json = """
        {"createdAt": \(Self.epoch), "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "claude-sonnet-4-5"}}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.date == localDateString(epochMillis: Self.epoch))
        #expect(entry?.amount == 3.0)
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
        // unifiedMode は UI モード（chat / 2 等）でありモデル ID ではない
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

/// `cursorDiskKV` を持つ最小の SQLite フィクスチャを作って scan() を検証する。
struct CursorUsageReaderScanTests {
    private func makeFixtureDB(rows: [(key: String, value: String)]) -> URL {
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

    private static let iso = "2025-10-02T06:19:31.163Z"

    @Test func bubbleId行だけ拾ってcomposerモデルで日別に合算する() {
        let db = makeFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "claude-4-sonnet"}}
             """),
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
             """),
            ("bubbleId:c1:b2", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}}
             """),
            ("composerData:other", "{\"modelConfig\": {\"modelName\": \"gpt-5\"}}"),
            ("bubbleId:c1:broken", "{not json")
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        let day = localDateString(iso: Self.iso)
        let month = String(day.prefix(7))
        let totals = CursorUsageReader.scan(dbPath: db.path, from: "\(month)-01", to: "\(month)-31")
        #expect(totals[day] == 6.0)   // 1M + 1M input * $3/MTok
        #expect(totals.count == 1)
    }

    @Test func bubbleのmodelInfoがcomposerより優先される() {
        let db = makeFixtureDB(rows: [
            ("composerData:c1", """
             {"modelConfig": {"modelName": "gpt-5"}}
             """),
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "claude-4-sonnet"}}
             """)
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        let day = localDateString(iso: Self.iso)
        let totals = CursorUsageReader.scan(dbPath: db.path, from: day, to: day)
        // sonnet $3, not gpt-5 $1.25
        #expect(totals[day] == 3.0)
    }

    @Test func 期間の外は集計に含めない() {
        let db = makeFixtureDB(rows: [
            ("bubbleId:c1:b1", """
             {"createdAt": "\(Self.iso)", "tokenCount": {"inputTokens": 1000000, "outputTokens": 0}, "modelInfo": {"modelName": "claude-sonnet-4-5"}}
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

/// CostDriver 準拠としての isAvailable / dailyCosts の zero-setup 劣化を確認する。
struct CursorCostDriverTests {
    @Test func ファイルが無ければ利用不可で空を返す() async {
        let driver = CursorCostDriver(stateDBURL: URL(fileURLWithPath: "/nonexistent/state.vscdb"))
        #expect(driver.isAvailable == false)
        let costs = await driver.dailyCosts(from: "2026-01-01", to: "2026-12-31")
        #expect(costs.isEmpty)
    }

    @Test func ファイルがあれば利用可能() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-avail-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let driver = CursorCostDriver(stateDBURL: url)
        #expect(driver.isAvailable)
    }

    /// CI / Cursor 未導入マシンではスキップ。導入済みマシンでは旧スキーマ想定だと
    /// 全件スキップされて 0 になるので、実データ対応の回帰検知になる。
    @Test func 実機のstate_vscdbがあれば正のコスト日が1日以上ある() {
        let path = CursorCostDriver.defaultStateDBURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }

        let totals = CursorUsageReader.scan(
            dbPath: path,
            from: "2020-01-01",
            to: "2035-12-31"
        )
        let sum = totals.values.reduce(0, +)
        #expect(sum > 0)
        #expect(totals.contains { $0.value > 0 })
    }
}
