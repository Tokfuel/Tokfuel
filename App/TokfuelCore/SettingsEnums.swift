import Foundation

/// retok の集計言語。auto は OS のロケールに従う。
public enum ReportLanguage: String, CaseIterable, Identifiable, Sendable {
    case auto, en, ja
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto: return "自動 (OS 設定)"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
    /// retok に渡す実際の言語コード。
    public var resolved: String {
        switch self {
        case .auto: return Locale.current.language.languageCode?.identifier ?? "en"
        case .en: return "en"
        case .ja: return "ja"
        }
    }
}

/// 予算の集計期間の起点。
public enum BudgetPeriod: String, CaseIterable, Identifiable, Sendable {
    case rolling30
    case calendarMonth
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .rolling30: return "過去 30 日間（今日から遡る）"
        case .calendarMonth: return "今月（1 日から）"
        }
    }
}

/// 予算のしきい値に達したときの知らせ方。
public enum BudgetAlertStyle: String, CaseIterable, Identifiable, Sendable {
    case notification
    case alert
    case both
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .notification: return "通知"
        case .alert: return "アラートウィンドウ"
        case .both: return "通知とアラートウィンドウ"
        }
    }
    public var usesNotification: Bool { self != .alert }
    public var usesAlertWindow: Bool { self != .notification }
}

/// 「今週」の週始まり。Calendar.weekday（1 = 日曜 … 7 = 土曜）に対応する。
public enum WeekStart: String, CaseIterable, Identifiable, Sendable {
    case saturday, sunday, monday
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .saturday: return "土曜日"
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        }
    }
    public var weekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .saturday: return 7
        }
    }
}

/// 推移チャートとコストレポートの集計窓（暦ベース。日数は日々変わる）。
public enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case today, thisWeek, thisMonth, thisYear
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        case .thisYear: return "今年"
        }
    }

    public static func migrated(fromLegacyDays days: Int) -> ReportPeriod {
        switch days {
        case 1: return .today
        case 7: return .thisWeek
        case 365: return .thisYear
        default: return .thisMonth
        }
    }
}

/// アプリ UI の外観。既定は macOS の外観に追従する。
public enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
}
