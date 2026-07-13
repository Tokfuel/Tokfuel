import Foundation

// ClaudeQuotaService の headless テスト。実行方法:
//   swiftc -parse-as-library -swift-version 6 Tokfuel/Sources/ClaudeQuota.swift \
//     tests/ClaudeQuotaTests.swift -o /tmp/claude_quota_tests && /tmp/claude_quota_tests
// レスポンス形式は CodexBar (MIT) の実装調査に基づく。

nonisolated(unsafe) var failures = 0
func expect(_ cond: Bool, _ label: String) {
    if cond { print("ok: \(label)") } else { failures += 1; print("FAIL: \(label)") }
}

@main
struct Tests {
    static func main() {
        // --- プラン表示名 ---
        expect(ClaudeQuotaService.planLabel(rateLimitTier: "default_claude_max_5x",
                                            organizationType: "claude_enterprise") == "Max 5x",
               "max_5x tier wins over org type")
        expect(ClaudeQuotaService.planLabel(rateLimitTier: "default_claude_max_20x",
                                            organizationType: nil) == "Max 20x", "max_20x tier")
        expect(ClaudeQuotaService.planLabel(rateLimitTier: nil,
                                            organizationType: "claude_enterprise") == "Enterprise",
               "org enterprise fallback")
        expect(ClaudeQuotaService.planLabel(rateLimitTier: nil, organizationType: nil) == nil,
               "nothing known yields nil")

        // --- credentials のパース（失効チェック含む） ---
        let now = ISO8601DateFormatter().date(from: "2026-07-13T12:00:00Z")!
        let valid = """
        {"claudeAiOauth":{"accessToken":"tok-abc","refreshToken":"r","expiresAt":\(UInt64(now.timeIntervalSince1970 * 1000) + 3_600_000),"scopes":["user:profile"],"subscriptionType":"max"}}
        """
        expect(ClaudeQuotaService.parseAccessToken(from: Data(valid.utf8), now: now) == "tok-abc",
               "valid token parsed")
        let expired = valid.replacingOccurrences(of: "\(UInt64(now.timeIntervalSince1970 * 1000) + 3_600_000)",
                                                 with: "\(UInt64(now.timeIntervalSince1970 * 1000) - 1000)")
        expect(ClaudeQuotaService.parseAccessToken(from: Data(expired.utf8), now: now) == nil,
               "expired token rejected (no self-refresh)")
        expect(ClaudeQuotaService.parseAccessToken(from: Data("{\"mcpOAuth\":{}}".utf8), now: now) == nil,
               "mcpOAuth-only payload (Claude Code 2.1.x file) yields nil")

        // --- usage レスポンスのパース ---
        let usage = """
        {"five_hour":{"utilization":42.5,"resets_at":"2026-07-13T15:00:00Z"},
         "seven_day":{"utilization":81.0,"resets_at":"2026-07-16T00:00:00Z"},
         "seven_day_opus":{"utilization":10.0,"resets_at":null},
         "extra_usage":{"is_enabled":false}}
        """
        let snap = ClaudeQuotaService.parse(data: Data(usage.utf8), now: now)
        expect(snap?.fiveHour?.percent == 42.5, "five_hour utilization")
        expect(snap?.fiveHour?.resetsAt == ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z"),
               "five_hour resets_at parsed")
        expect(snap?.sevenDay?.percent == 81.0, "seven_day utilization")
        expect(snap?.sevenDayOpus?.percent == 10.0, "opus window optional resets_at tolerated")
        expect(ClaudeQuotaService.parse(data: Data("{}".utf8)) == nil,
               "response without windows is rejected")
        expect(ClaudeQuotaService.parse(data: Data("not json".utf8)) == nil,
               "non-JSON rejected")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all tests passed")
    }
}
