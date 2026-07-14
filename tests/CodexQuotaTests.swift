import Foundation

// CodexQuotaService の headless テスト。実行方法:
//   swiftc -parse-as-library -swift-version 6 Tokfuel/Sources/CodexQuota.swift \
//     tests/CodexQuotaTests.swift -o /tmp/codex_quota_tests && /tmp/codex_quota_tests
// レスポンス形式は CodexBar (MIT) の実装調査（wham/usage）に基づく。

nonisolated(unsafe) var failures = 0
func expect(_ cond: Bool, _ label: String) {
    if cond { print("ok: \(label)") } else { failures += 1; print("FAIL: \(label)") }
}

/// テスト用の署名なし JWT（header.payload.signature の payload だけ本物の形）。
func jwt(exp: Double) -> String {
    let payload = try! JSONSerialization.data(withJSONObject: ["exp": exp])
    let b64 = payload.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJub25lIn0.\(b64).sig"
}

@main
struct Tests {
    static func main() {
        let now = ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z")!

        // --- auth.json のパースと失効判定 ---
        let future = now.timeIntervalSince1970 + 3600
        let valid = """
        {"auth_mode":"chatgpt","tokens":{"id_token":"x","access_token":"\(jwt(exp: future))","refresh_token":"r","account_id":"acc-1"},"last_refresh":"2026-07-13T03:13:41Z"}
        """
        let creds = CodexQuotaService.parseCredentials(from: Data(valid.utf8), now: now)
        expect(creds != nil, "valid auth.json parsed")
        expect(creds?.accountId == "acc-1", "account_id extracted")
        let expired = """
        {"tokens":{"access_token":"\(jwt(exp: now.timeIntervalSince1970 - 1))"}}
        """
        expect(CodexQuotaService.parseCredentials(from: Data(expired.utf8), now: now) == nil,
               "expired JWT rejected (no self-refresh)")
        expect(CodexQuotaService.parseCredentials(from: Data("{}".utf8), now: now) == nil,
               "missing tokens yields nil")
        expect(CodexQuotaService.jwtExpiry(of: "not-a-jwt") == nil,
               "unparseable JWT skips expiry check")

        // --- wham/usage レスポンスのパース ---
        let usage = """
        {"plan_type":"business",
         "rate_limit":{
           "primary_window":{"used_percent":42,"reset_at":1784100000,"limit_window_seconds":18000},
           "secondary_window":{"used_percent":80.5,"reset_at":1784500000,"limit_window_seconds":604800}},
         "credits":{"has_credits":true,"unlimited":false,"balance":null}}
        """
        let snap = CodexQuotaService.parse(data: Data(usage.utf8), now: now)
        expect(snap?.planType == "business", "plan_type parsed")
        expect(snap?.primary?.percent == 42, "primary used_percent (Int) parsed")
        expect(snap?.secondary?.percent == 80.5, "secondary used_percent (Double) parsed")
        expect(snap?.primary?.windowMinutes == 300, "5h window minutes")
        expect(snap?.primary?.resetsAt == Date(timeIntervalSince1970: 1784100000),
               "reset_at unix seconds parsed")
        expect(CodexQuotaService.parse(data: Data("{}".utf8)) == nil,
               "empty response rejected")
        // rate_limit の窓が無くても plan_type だけの応答は活かす。
        expect(CodexQuotaService.parse(data: Data(#"{"plan_type":"plus"}"#.utf8))?.planType == "plus",
               "plan-only response kept")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all tests passed")
    }
}
