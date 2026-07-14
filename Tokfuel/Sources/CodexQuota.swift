import Foundation

/// Codex 側のサーバークォータ（プランと 5h / 週次ウィンドウ）。
struct CodexQuotaSnapshot: Sendable {
    struct Window: Sendable {
        let percent: Double        // used_percent (0–100)
        let resetsAt: Date?
        let windowMinutes: Int?
    }
    var planType: String?
    var primary: Window?           // 5 時間ウィンドウ
    var secondary: Window?         // 週次ウィンドウ
    let fetchedAt: Date
}

/// Codex CLI が保存した OAuth トークンで ChatGPT backend の使用量 API を叩く
/// （CU-0007 の Codex 版）。**オプトイン**（`AppSettings.codexQuotaEnabled`、既定 OFF）。
/// 送信するのは `~/.codex/auth.json` の自分のトークンだけで、宛先は OpenAI
/// （chatgpt.com）のみ。トークンの更新・auth.json への書き込みは行わない
/// （失効時は codex CLI を一度実行すると更新される）。
/// 手法は CodexBar (MIT, © Peter Steinberger) の実装調査に基づく。
enum CodexQuotaService {
    enum QuotaError: LocalizedError {
        case noCredentials
        case tokenExpired
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noCredentials:
                return "Codex CLI の認証情報が見つかりません"
            case .tokenExpired:
                return "Codex のトークンが失効しています。codex を一度実行すると更新されます"
            case .http(let code):
                return code == 401
                    ? "Codex の認証エラー (401)。codex を一度実行すると更新されます"
                    : "Codex の取得に失敗しました (HTTP \(code))"
            case .badResponse:
                return "Codex の応答を解釈できませんでした"
            }
        }
    }

    struct Credentials {
        let accessToken: String
        let accountId: String?
    }

    // MARK: - 認証情報（読み取りのみ・更新しない）

    static var defaultAuthPath: String { NSHomeDirectory() + "/.codex/auth.json" }

    static func credentials(authPath: String = defaultAuthPath,
                            now: Date = Date()) -> Credentials? {
        guard let data = FileManager.default.contents(atPath: authPath) else { return nil }
        return parseCredentials(from: data, now: now)
    }

    /// `{"tokens":{"access_token":..., "account_id":...}}`。JWT の exp で失効を先に弾く。
    static func parseCredentials(from data: Data, now: Date = Date()) -> Credentials? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = obj["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String, !token.isEmpty else { return nil }
        if let exp = jwtExpiry(of: token), exp <= now { return nil }
        return Credentials(accessToken: token,
                           accountId: tokens["account_id"] as? String)
    }

    /// JWT の `exp` クレーム（unix 秒）。形式が読めない場合は nil（= 失効チェックなしで通す）。
    static func jwtExpiry(of jwt: String) -> Date? {
        let segments = jwt.split(separator: ".")
        guard segments.count == 3 else { return nil }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    // MARK: - 取得

    /// `GET https://chatgpt.com/backend-api/wham/usage`（Codex 公式クライアントと同じ経路）。
    static func fetch() async throws -> CodexQuotaSnapshot {
        guard let creds = credentials() else { throw QuotaError.noCredentials }
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId = creds.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw QuotaError.badResponse }
        guard http.statusCode == 200 else { throw QuotaError.http(http.statusCode) }
        guard let snapshot = parse(data: data) else { throw QuotaError.badResponse }
        return snapshot
    }

    /// レスポンス例:
    /// {"plan_type":"business","rate_limit":{"primary_window":{"used_percent":42,
    ///   "reset_at":1770000000,"limit_window_seconds":18000},"secondary_window":{...}}}
    static func parse(data: Data, now: Date = Date()) -> CodexQuotaSnapshot? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let rateLimit = obj["rate_limit"] as? [String: Any]
        func window(_ key: String) -> CodexQuotaSnapshot.Window? {
            guard let w = rateLimit?[key] as? [String: Any],
                  let percent = (w["used_percent"] as? NSNumber)?.doubleValue else { return nil }
            let resets = (w["reset_at"] as? NSNumber).map {
                Date(timeIntervalSince1970: $0.doubleValue)
            }
            let minutes = (w["limit_window_seconds"] as? NSNumber).map { Int($0.intValue / 60) }
            return .init(percent: percent, resetsAt: resets, windowMinutes: minutes)
        }
        let snapshot = CodexQuotaSnapshot(planType: obj["plan_type"] as? String,
                                          primary: window("primary_window"),
                                          secondary: window("secondary_window"),
                                          fetchedAt: now)
        guard snapshot.primary != nil || snapshot.secondary != nil || snapshot.planType != nil
        else { return nil }
        return snapshot
    }
}
