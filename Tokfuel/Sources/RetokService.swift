import Foundation

/// retok --json の出力。コスト・トークン・キャッシュ効率・推奨事項を保持する。
/// Encodable も付けているのは ReportCache（前回レポートのディスク保存）のため。
struct RetokReport: Codable {
    struct Totals: Codable {
        var cost: Double = 0
        var input: Int = 0
        var output: Int = 0
        var cacheRead: Int = 0
        var cacheWrite: Int = 0
        var prompts: Int = 0
        var requests: Int = 0

        enum CodingKeys: String, CodingKey {
            case cost, input, output, prompts, requests
            case cacheRead = "cache_read"
            case cacheWrite = "cache_write"
        }
    }

    struct ModelUsage: Codable {
        var cost: Double = 0
        var input: Int = 0
        var output: Int = 0
        var requests: Int = 0
    }

    struct DailyCost: Codable {
        var cost: Double = 0
        var output: Int = 0
    }

    struct Advice: Codable, Identifiable {
        let severity: String   // "high" / "info" など
        let key: String
        let title: String
        let detail: String
        var id: String { key }
    }

    struct TopSession: Codable, Identifiable {
        let session: String
        let project: String
        let cost: Double
        let prompts: Int
        let maxContext: Int
        var id: String { session }

        enum CodingKeys: String, CodingKey {
            case session, project, cost, prompts
            case maxContext = "max_context"
        }
    }

    let periodDays: Int
    let filesScanned: Int
    let totals: Totals
    let cacheHitRate: Double
    let perModel: [String: ModelUsage]
    let daily: [String: DailyCost]
    let advice: [Advice]
    let topSessions: [TopSession]

    enum CodingKeys: String, CodingKey {
        case totals, daily, advice
        case periodDays = "period_days"
        case filesScanned = "files_scanned"
        case cacheHitRate = "cache_hit_rate"
        case perModel = "per_model"
        case topSessions = "top_sessions"
    }

    /// 日付昇順の (date, cost) 列。グラフ用。
    var dailySorted: [(date: String, cost: Double)] {
        daily.map { (date: $0.key, cost: $0.value.cost) }.sorted { $0.date < $1.date }
    }

    /// コスト降順のモデル別内訳。
    var modelsSorted: [(model: String, usage: ModelUsage)] {
        perModel.map { (model: $0.key, usage: $0.value) }.sorted { $0.usage.cost > $1.usage.cost }
    }

    func cost(on date: String) -> Double? { daily[date]?.cost }
}

/// バンドルした retok（Python スクリプト）を実行して JSON レポートを得る。
/// アプリに同梱しているため、ユーザー側のインストール作業は不要。
enum RetokService {
    enum RetokError: LocalizedError {
        case scriptMissing
        case pythonMissing
        case runFailed(String)

        var errorDescription: String? {
            switch self {
            case .scriptMissing: return "同梱の retok スクリプトが見つかりません"
            case .pythonMissing: return "python3 が見つかりません（Xcode Command Line Tools が必要です）"
            case .runFailed(let msg): return "retok の実行に失敗しました: \(msg)"
            }
        }
    }

    /// python3 の実体を探す。CLT 未インストールの /usr/bin/python3 シムでの失敗を避けるため実在を確認する。
    private static func findPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            // /usr/bin/python3 は CLT 未導入だとエラー終了するシムなので、実際に動くか確かめる
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = ["-c", "pass"]
            p.standardError = FileHandle.nullDevice
            p.standardOutput = FileHandle.nullDevice
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus == 0 { return path }
            } catch { continue }
        }
        return nil
    }

    /// retok をバックグラウンドで実行してレポートを返す。
    /// projectsDir を渡すと retok の走査元 (`--dirs`) を上書きする（既定は retok 内蔵の ~/.claude/projects）。
    /// provider を渡すと retok の `--provider claude|codex` で片方だけに絞る（既定は両方合算）。
    static func run(days: Int, lang: String, projectsDir: URL? = nil, provider: String? = nil) async throws -> RetokReport {
        guard let script = Bundle.module.url(forResource: "retok", withExtension: "py") else {
            throw RetokError.scriptMissing
        }
        guard let python = findPython() else {
            throw RetokError.pythonMissing
        }

        return try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            var arguments = [script.path, "--json", "--days", "\(days)", "--lang", lang]
            if let projectsDir {
                arguments += ["--dirs", projectsDir.path]
            }
            if let provider {
                arguments += ["--provider", provider]
            }
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let msg = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? "unknown"
                throw RetokError.runFailed(String(msg.prefix(200)))
            }
            return try JSONDecoder().decode(RetokReport.self, from: data)
        }.value
    }
}
