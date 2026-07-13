import Foundation

// PeriodFilter の headless テスト。実行方法:
//   swiftc -parse-as-library -swift-version 6 Tokfuel/Sources/PeriodFilter.swift \
//     tests/PeriodFilterTests.swift -o /tmp/period_filter_tests && /tmp/period_filter_tests

nonisolated(unsafe) var failures = 0   // 単一スレッドのテストランナー専用
func expect(_ cond: Bool, _ label: String) {
    if cond { print("ok: \(label)") } else { failures += 1; print("FAIL: \(label)") }
}

@main
struct Tests {
    static func main() {
        // ローカルタイムに依存しないよう、正午 UTC を基準にする（どの TZ でも同じ暦日）。
        let now = ISO8601DateFormatter().date(from: "2026-07-13T12:00:00Z")!
        let cal = Calendar(identifier: .gregorian)
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: now)
        let daysAgo: (Int) -> String = { f.string(from: cal.date(byAdding: .day, value: -$0, to: now)!) }

        expect(PeriodFilter.today.minDateString(now: now) == today, "today window starts today")
        expect(PeriodFilter.days7.minDateString(now: now) == daysAgo(6), "7d includes today (6 back)")
        expect(PeriodFilter.days30.minDateString(now: now) == daysAgo(29), "30d includes today (29 back)")
        expect(PeriodFilter.all.minDateString(now: now) == nil, "all is unbounded")

        expect(PeriodFilter.today.includes(date: today, now: now), "today includes today")
        expect(!PeriodFilter.today.includes(date: daysAgo(1), now: now), "today excludes yesterday")
        expect(PeriodFilter.days7.includes(date: daysAgo(6), now: now), "7d includes 6 days ago")
        expect(!PeriodFilter.days7.includes(date: daysAgo(7), now: now), "7d excludes 7 days ago")
        expect(PeriodFilter.all.includes(date: "2000-01-01", now: now), "all includes ancient date")

        // rawValue は UserDefaults 保存値として安定していること。
        expect(PeriodFilter(rawValue: "7d") == .days7, "rawValue roundtrip 7d")
        expect(PeriodFilter(rawValue: "today") == .today, "rawValue roundtrip today")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all tests passed")
    }
}
