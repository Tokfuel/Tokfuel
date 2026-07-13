import Foundation
import Security

/// サーバー側クォータのスナップショット（CU-0007）。公式 `/usage` と同じ数字。
struct ClaudeQuotaSnapshot: Sendable {
    struct Window: Sendable {
        let percent: Double        // 使用率 (0–100)
        let resetsAt: Date?
    }
    var fiveHour: Window?
    var sevenDay: Window?
    var sevenDayOpus: Window?
    let fetchedAt: Date
}

/// Claude のプラン・クォータをローカル資産から取得する（CU-0007 / CU-0010 の一部）。
///
/// - プラン名: `~/.claude.json` の `oauthAccount`（ネットワーク不要・常時安全）。
/// - クォータ%: Claude Code が保存した OAuth トークン（`~/.claude/.credentials.json` または
///   Keychain "Claude Code-credentials"）で `api.anthropic.com/api/oauth/usage` を叩く。
///   これは**オプトイン**（`AppSettings.serverQuotaEnabled`、既定 OFF）。送信するのは
///   自分のトークンだけで、宛先は Anthropic のみ。使用データは送らない。
///   トークンの更新は行わない（Claude Code 側のローテーションと競合するため）。
///   手法は CodexBar (MIT, © Peter Steinberger) の調査に基づく。
enum ClaudeQuotaService {
    enum QuotaError: LocalizedError {
        case noCredentials
        case tokenExpired
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noCredentials:
                return "Claude Code の認証情報が見つかりません"
            case .tokenExpired:
                return "トークンが失効しています。Claude Code を一度開くと更新されます"
            case .http(let code):
                return code == 401
                    ? "認証エラー (401)。Claude Code を一度開くと更新されます"
                    : "取得に失敗しました (HTTP \(code))"
            case .badResponse:
                return "応答を解釈できませんでした"
            }
        }
    }

    // MARK: - プラン検出（ローカルのみ）

    /// `~/.claude.json` の `oauthAccount` からプラン表示名を導く。ネットワークは使わない。
    static func detectPlan(claudeConfigPath: String = NSHomeDirectory() + "/.claude.json") -> String? {
        guard let data = FileManager.default.contents(atPath: claudeConfigPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = obj["oauthAccount"] as? [String: Any] else { return nil }
        return planLabel(
            rateLimitTier: account["userRateLimitTier"] as? String,
            organizationType: account["organizationType"] as? String)
    }

    /// レートリミット層の識別子（例: "default_claude_max_5x"）を表示名にする。
    static func planLabel(rateLimitTier: String?, organizationType: String?) -> String? {
        if let tier = rateLimitTier {
            if tier.contains("max_20x") { return "Max 20x" }
            if tier.contains("max_5x") { return "Max 5x" }
            if tier.contains("pro") { return "Pro" }
            if tier.contains("free") { return "Free" }
        }
        if let org = organizationType, org.contains("enterprise") { return "Enterprise" }
        return rateLimitTier
    }

    // MARK: - 認証情報（読み取りのみ・更新しない）

    /// Claude Code が保存したアクセストークンを探す。ファイル → Keychain の順。
    static func accessToken() -> String? {
        if let token = tokenFromCredentialsFile() { return token }
        return tokenFromKeychain()
    }

    private static func tokenFromCredentialsFile() -> String? {
        let path = NSHomeDirectory() + "/.claude/.credentials.json"
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return parseAccessToken(from: data)
    }

    /// Keychain の generic password "Claude Code-credentials"（初回はユーザーに許可を求める
    /// ダイアログが出る）。
    private static func tokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return parseAccessToken(from: data)
    }

    /// `{"claudeAiOauth":{"accessToken":..., "expiresAt":<ms epoch>}}` からトークンを取り出す。
    /// 失効している場合は nil（自前で refresh しない）。
    static func parseAccessToken(from data: Data, now: Date = Date()) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        if let expiresAt = oauth["expiresAt"] as? Double,
           Date(timeIntervalSince1970: expiresAt / 1000) <= now { return nil }
        return token
    }

    // MARK: - 取得

    /// `GET /api/oauth/usage`。公式クライアントと同じヘッダを付ける。
    static func fetch() async throws -> ClaudeQuotaSnapshot {
        guard let token = accessToken() else { throw QuotaError.noCredentials }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw QuotaError.badResponse }
        guard http.statusCode == 200 else { throw QuotaError.http(http.statusCode) }
        guard let snapshot = parse(data: data) else { throw QuotaError.badResponse }
        return snapshot
    }

    /// レスポンス例: {"five_hour":{"utilization":42.5,"resets_at":"2026-07-13T15:00:00Z"}, ...}
    static func parse(data: Data, now: Date = Date()) -> ClaudeQuotaSnapshot? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        func window(_ key: String) -> ClaudeQuotaSnapshot.Window? {
            guard let w = obj[key] as? [String: Any],
                  let percent = w["utilization"] as? Double else { return nil }
            let resets = (w["resets_at"] as? String).flatMap {
                ISO8601DateFormatter().date(from: $0)
            }
            return .init(percent: percent, resetsAt: resets)
        }
        let snapshot = ClaudeQuotaSnapshot(fiveHour: window("five_hour"),
                                           sevenDay: window("seven_day"),
                                           sevenDayOpus: window("seven_day_opus"),
                                           fetchedAt: now)
        // どの窓も無い応答は形式が変わったとみなす。
        guard snapshot.fiveHour != nil || snapshot.sevenDay != nil else { return nil }
        return snapshot
    }
}
