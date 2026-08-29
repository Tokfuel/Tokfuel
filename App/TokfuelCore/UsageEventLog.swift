import Foundation

/// `~/Library/Application Support/Tokfuel` — アプリの永続データ置き場。
/// トランスクリプトキャッシュとイベントログが共有する（改名時に二重管理しないため）。
public enum AppSupport {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tokfuel", isDirectory: true)
    }
}

public enum UsageEvent: String {
    case appLaunch = "app_launch"
    case popoverOpen = "popover_open"
    case tabOpen = "tab_open"
    case periodChange = "period_change"
    case settingsOpen = "settings_open"
    case settingChange = "setting_change"
    case notificationShown = "notification_shown"
    case alertShown = "alert_shown"
    case experimentExposure = "experiment_exposure"   // CU-0014 用の予約
}

public final class UsageEventLog: @unchecked Sendable {
    public static let shared = UsageEventLog()

    public static let enabledKey = "eventLogEnabled"
    public static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey)
    }

    public static let schemaVersion = 1
    public static let retentionMonths = 12

    private static let gregorian = Calendar(identifier: .gregorian)
    /// ないため、Swift 6 の検査を明示的に免除する。
    nonisolated(unsafe) private static let iso8601 = ISO8601DateFormatter()

    private let directory: URL
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.akidon0000.tokfuel.usage-event-log")
    private var didPrune = false

    public static var defaultDirectory: URL {
        AppSupport.directory.appendingPathComponent("events", isDirectory: true)
    }

    public init(directory: URL = UsageEventLog.defaultDirectory,
         defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
    }


    nonisolated(unsafe) public static var analyticsTracker: ((UsageEvent, [String: String]) -> Void)?

    /// イベントを 1 行追記する。無効時は何もしない。失敗は致命的ではないため握りつぶす。
    public func log(_ event: UsageEvent, meta: [String: String] = [:], at date: Date = Date()) {
        Self.analyticsTracker?(event, meta)
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
            }
        }
    }

    public static func encodeLine(event: UsageEvent, meta: [String: String], date: Date) -> Data? {
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


    public static func fileName(for date: Date) -> String {
        let comps = gregorian.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d.jsonl", comps.year ?? 0, comps.month ?? 0)
    }

    public static func isExpired(fileName name: String, now: Date) -> Bool {
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

    private func pruneIfNeeded() {
        guard !didPrune else { return }
        didPrune = true
        let now = Date()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where Self.isExpired(fileName: name, now: now) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }


    public func revealDirectoryURL() -> URL {
        queue.sync {
            try? FileManager.default.createDirectory(at: directory,
                                                     withIntermediateDirectories: true)
            return directory
        }
    }

    public func deleteAll() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
