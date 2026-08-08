import Foundation
import Testing
@testable import Tokfuel

/// retok --json 出力の縮小サンプル。実際のキー名（snake_case）と一致させている。
private let sampleJSON = Data("""
{
  "period_days": 7,
  "files_scanned": 12,
  "cache_hit_rate": 0.85,
  "totals": {"cost": 42.5, "input": 1000, "output": 2000,
             "cache_read": 500, "cache_write": 100, "prompts": 10, "requests": 20},
  "per_model": {
    "claude-fable-5": {"cost": 40.0, "input": 900, "output": 1800, "requests": 15},
    "claude-haiku-4-5": {"cost": 2.5, "input": 100, "output": 200, "requests": 5}
  },
  "daily": {
    "2026-07-27": {"cost": 12.5, "output": 800},
    "2026-07-28": {"cost": 30.0, "output": 1200}
  },
  "advice": [
    {"severity": "high", "key": "cache-ttl", "title": "t", "detail": "d"}
  ],
  "top_sessions": [
    {"session": "s1", "project": "org/repo", "cost": 9.9, "prompts": 3, "max_context": 120000}
  ]
}
""".utf8)

struct RetokReportTests {
    private func decode() throws -> RetokReport {
        try JSONDecoder().decode(RetokReport.self, from: sampleJSON)
    }

    @Test func サンプルJSONをデコードできる() throws {
        let report = try decode()
        #expect(report.periodDays == 7)
        #expect(report.filesScanned == 12)
        #expect(report.totals.cost == 42.5)
        #expect(report.totals.cacheRead == 500)
        #expect(report.cacheHitRate == 0.85)
        #expect(report.advice.first?.id == "cache-ttl")
        #expect(report.topSessions.first?.maxContext == 120_000)
    }

    @Test func 日次は日付昇順に並ぶ() throws {
        let days = try decode().dailySorted
        #expect(days.map(\.date) == ["2026-07-27", "2026-07-28"])
        #expect(days.last?.cost == 30.0)
    }

    @Test func モデル別はコスト降順に並ぶ() throws {
        let models = try decode().modelsSorted
        #expect(models.map(\.model) == ["claude-fable-5", "claude-haiku-4-5"])
    }

    @Test func 特定日のコストを引ける() throws {
        let report = try decode()
        #expect(report.cost(on: "2026-07-28") == 30.0)
        #expect(report.cost(on: "2026-01-01") == nil)
    }

    /// 追従モード（TF-0080）は 1 日ぶんの結果を長期集計に重ねる。
    /// 日別だけが差し替わり、期間・合計・モデル別は元のまま残る。
    @Test func 日別だけを重ねられる() throws {
        let report = try decode()
        let merged = report.merging(daily: ["2026-07-28": .init(cost: 44.0, output: 10),
                                            "2026-07-29": .init(cost: 5.0, output: 1)])
        #expect(merged.cost(on: "2026-07-28") == 44.0)   // 上書き
        #expect(merged.cost(on: "2026-07-29") == 5.0)    // 追加
        #expect(merged.cost(on: "2026-07-27") == report.cost(on: "2026-07-27"))   // 据え置き
        #expect(merged.totals.cost == report.totals.cost)
        #expect(merged.periodDays == report.periodDays)
        #expect(merged.modelsSorted.map(\.model) == report.modelsSorted.map(\.model))
    }
}
