import Foundation

/// `~/Library/Application Support/Tokfuel` — アプリの永続データ置き場。
/// トランスクリプトキャッシュとイベントログが共有する（改名時に二重管理しないため）。
enum AppSupport {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tokfuel", isDirectory: true)
    }
}

/// Tokfuel 自身の UI 利用イベント（CU-0013）。名前は JSONL 上の `event` 値になる。
enum UsageEvent: String {
    case popoverOpen = "popover_open"
    case tabOpen = "tab_open"
    case periodChange = "period_change"
    case settingsOpen = "settings_open"
    case settingChange = "setting_change"
    case notificationShown = "notification_shown"
    case experimentExposure = "experiment_exposure"   // CU-0014 用の予約
}

/// アプリ自身の利用イベントをローカル JSONL に追記する（CU-0013）。
/// 記録するのは Tokfuel の UI イベントだけで、トランスクリプト内容・プロジェクト名・
/// コストは決して書かない。データは Mac の外に出ない（原則 1）。
/// 通知経路（BudgetMonitor）など MainActor 外からも呼べるよう、直列キューで書き込む。
final class UsageEventLog: @unchecked Sendable {
    static let shared = UsageEventLog()

    /// 記録の ON/OFF の UserDefaults キー。既定値の解釈は `isEnabled(in:)` の一箇所に置き、
    /// `AppSettings.eventLogEnabled`（設定画面のトグル）も同じ実装を読む。
    static let enabledKey = "eventLogEnabled"
    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey)
    }

    static let schemaVersion = 1
    static let retentionMonths = 12

    /// ファイル名とタイムスタンプはユーザーの地域設定（和暦など）に依存させない。
    private static let gregorian = Calendar(identifier: .gregorian)
    /// ISO8601DateFormatter はスレッド安全（Apple のドキュメント明記）だが Sendable 宣言が
    /// ないため、Swift 6 の検査を明示的に免除する。
    nonisolated(unsafe) private static let iso8601 = ISO8601DateFormatter()

    private let directory: URL
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.akidon0000.tokfuel.usage-event-log")
    private var didPrune = false

    /// 既定の保存先: ~/Library/Application Support/Tokfuel/events/
    static var defaultDirectory: URL {
        AppSupport.directory.appendingPathComponent("events", isDirectory: true)
    }

    init(directory: URL = UsageEventLog.defaultDirectory,
         defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
    }

    // MARK: - 書き込み

    /// イベントを 1 行追記する。無効時は何もしない。失敗は致命的ではないため握りつぶす。
    func log(_ event: UsageEvent, meta: [String: String] = [:], at date: Date = Date()) {
        guard Self.isEnabled(in: defaults) else { return }
        guard let line = Self.encodeLine(event: event, meta: meta, date: date) else { return }
        queue.async { [self] in
            pruneIfNeeded()
            let file = directory.appendingPathComponent(Self.fileName(for: date))
            do {
                try FileManager.default.createDirectory(at: directory,
                                                        withIntermediateDirectories: true)
                if let handle = try? FileHandle(forWritingTo: file) {
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } else {
                    try line.write(to: file)
                }
            } catch {
                // ログ欠落はアプリの動作に影響させない。
            }
        }
    }

    /// {"v":1,"ts":"…","event":"…","meta":{…}} + 改行。キーはテスト安定のためソートする。
    static func encodeLine(event: UsageEvent, meta: [String: String], date: Date) -> Data? {
        struct Line: Encodable {
            let v: Int
            let ts: String
            let event: String
            let meta: [String: String]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let line = Line(v: schemaVersion,
                        ts: iso8601.string(from: date),
                        event: event.rawValue,
                        meta: meta)
        guard var data = try? encoder.encode(line) else { return nil }
        data.append(0x0A)
        return data
    }

    // MARK: - ローテーションと削除

    /// 月ごとのファイル名（YYYY-MM.jsonl）。グレゴリオ暦・ローカルタイムゾーンで切る。
    static func fileName(for date: Date) -> String {
        let comps = gregorian.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d.jsonl", comps.year ?? 0, comps.month ?? 0)
    }

    /// retentionMonths より古い月のファイル名なら true。不正な名前は消さない。
    /// ゼロ埋めの YYYY-MM は辞書順 = 時系列なので文字列比較で足りる。
    static func isExpired(fileName name: String, now: Date) -> Bool {
        guard name.hasSuffix(".jsonl"), isValidMonthStem(name) ,
              let cutoff = gregorian.date(byAdding: .month, value: -retentionMonths, to: now)
        else { return false }
        return name < fileName(for: cutoff)
    }

    private static func isValidMonthStem(_ name: String) -> Bool {
        let stem = name.replacingOccurrences(of: ".jsonl", with: "")
        let parts = stem.split(separator: "-")
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              Int(parts[0]) != nil, let m = Int(parts[1]), (1...12).contains(m)
        else { return false }
        return true
    }

    /// プロセスにつき 1 回、保持期間を過ぎた月ファイルを削除する。queue 上で呼ぶこと。
    /// 基準時刻はイベントの日時ではなく常に現在時刻（過去日時のイベントに引きずられない）。
    private func pruneIfNeeded() {
        guard !didPrune else { return }
        didPrune = true
        let now = Date()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where Self.isExpired(fileName: name, now: now) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    // MARK: - 読み出し

    /// 直近 `days` 日のイベント件数（gardener と設定画面の表示用）。
    /// 期間より前の月ファイルは開かずに飛ばす。
    func frequency(of event: UsageEvent, days: Int, now: Date = Date()) -> Int {
        queue.sync {
            let since = Self.gregorian.date(byAdding: .day, value: -days, to: now) ?? now
            let firstRelevantFile = Self.fileName(for: since)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            var count = 0
            for name in names.sorted()
            where name.hasSuffix(".jsonl") && name >= firstRelevantFile {
                guard let text = try? String(contentsOf: directory.appendingPathComponent(name),
                                             encoding: .utf8) else { continue }
                count += Self.countMatches(in: text, event: event, since: since)
            }
            return count
        }
    }

    /// JSONL テキストから、`since` 以降の該当イベント行を数える。壊れた行は無視する。
    static func countMatches(in text: String, event: UsageEvent, since: Date) -> Int {
        var count = 0
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["event"] as? String == event.rawValue,
                  let ts = obj["ts"] as? String,
                  let date = iso8601.date(from: ts),
                  date >= since else { continue }
            count += 1
        }
        return count
    }

    // MARK: - 管理操作（設定画面から）

    /// Finder で開くための保存先。未作成でもボタンが無反応にならないよう、先に作る。
    func revealDirectoryURL() -> URL {
        queue.sync {
            try? FileManager.default.createDirectory(at: directory,
                                                     withIntermediateDirectories: true)
            return directory
        }
    }

    /// 全イベントを削除する。結果を待つ必要はないため非同期（直列キューが順序を保証）。
    func deleteAll() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
