import Foundation
import SQLite3
import Testing
@testable import Tokfuel

/// テスト用のエポックミリ秒 → "YYYY-MM-DD"。実装側（CursorUsageReader.dayString）と同じ
/// UsageStore.dateString を使う——固定の日付文字列をハードコードすると CI のタイムゾーン
/// 次第で日付がずれてテストが壊れるため、常にこの関数で期待値を作る。実装が使う変換と別の
/// コピーを持つと、どちらかだけがタイムゾーンバグを踏んでもテストが気づけなくなる。
private func localDateString(epochMillis: Double) -> String {
    UsageStore.dateString(Date(timeIntervalSince1970: epochMillis / 1000))
}

/// Cursor の state.vscdb スキーマは非公開でリバースエンジニアリングに基づく想定でしかない
/// （CursorCostDriver.swift のコメント参照）。ここでは「想定した形」に対する振る舞いだけを
/// 検証する——実機の Cursor データに対する正しさはこのテストでは保証できない。
struct CursorCostDriverParsingTests {
    private static let epoch: Double = 1785312000000

    @Test func トークンとモデルが揃っていれば日付とコストを返す() {
        let json = """
        {"createdAt": \(Self.epoch), "inputTokens": 1000000, "outputTokens": 500000, "model": "claude-sonnet-4-5"}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.date == localDateString(epochMillis: Self.epoch))
        #expect(entry?.amount == 3.0 + 7.5)   // 1M*$3 + 0.5M*$15
    }

    @Test func モデル不明ならコストはゼロだが日付は取れる() {
        let json = """
        {"createdAt": \(Self.epoch), "inputTokens": 100, "outputTokens": 50, "model": "some-future-model"}
        """
        let entry = CursorUsageReader.costEntry(fromBubbleJSON: json)
        #expect(entry?.date == localDateString(epochMillis: Self.epoch))
        #expect(entry?.amount == 0)
    }

    @Test func createdAtが無ければnil() {
        let json = """
        {"inputTokens": 100, "outputTokens": 50, "model": "claude-sonnet-4-5"}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
    }

    @Test func トークンが両方ゼロならnil() {
        let json = """
        {"createdAt": 1785312000000, "inputTokens": 0, "outputTokens": 0, "model": "claude-sonnet-4-5"}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
    }

    @Test func 壊れたJSONはnil() {
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: "{not json") == nil)
    }

    @Test func 想定外の型でもクラッシュしない() {
        let json = """
        {"createdAt": "not-a-number", "inputTokens": "lots", "outputTokens": null, "model": 42}
        """
        #expect(CursorUsageReader.costEntry(fromBubbleJSON: json) == nil)
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

    private static let epoch: Double = 1785312000000

    @Test func bubbleId行だけ拾って日別に合算する() {
        let db = makeFixtureDB(rows: [
            ("bubbleId:c1:b1", """
             {"createdAt": \(Self.epoch), "inputTokens": 1000000, "outputTokens": 0, "model": "claude-sonnet-4-5"}
             """),
            ("bubbleId:c1:b2", """
             {"createdAt": \(Self.epoch), "inputTokens": 1000000, "outputTokens": 0, "model": "claude-sonnet-4-5"}
             """),
            ("composerData:c1", "{\"unrelated\": true}"),   // bubbleId: プレフィックスではないので除外
            ("bubbleId:c1:broken", "{not json")             // 壊れた行は無視される
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        // 対象の日付を含む区間として、その月の初日から末日までを丸ごと使う。
        let day = localDateString(epochMillis: Self.epoch)
        let month = String(day.prefix(7))
        let totals = CursorUsageReader.scan(dbPath: db.path, from: "\(month)-01", to: "\(month)-31")
        #expect(totals[day] == 6.0)   // 1M + 1M input * $3/MTok
        #expect(totals.count == 1)
    }

    @Test func 期間の外は集計に含めない() {
        let db = makeFixtureDB(rows: [
            ("bubbleId:c1:b1", """
             {"createdAt": \(Self.epoch), "inputTokens": 1000000, "outputTokens": 0, "model": "claude-sonnet-4-5"}
             """)
        ])
        defer { try? FileManager.default.removeItem(at: db) }

        // 対象日から確実に 1 年以上離れた区間を使う（タイムゾーンでどうずれても外れる）。
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
}
