import Foundation

/// Tools タブの集計期間（CU-0011）。rawValue は UserDefaults への保存値。
enum PeriodFilter: String, CaseIterable {
    case today
    case days7 = "7d"
    case days30 = "30d"
    case all

    var label: String {
        switch self {
        case .today: return "Today"
        case .days7: return "7d"
        case .days30: return "30d"
        case .all: return "All"
        }
    }

    /// 集計に含める最古の日付 (YYYY-MM-DD)。`all` は nil（無制限）。
    /// 「7d」は今日を含む直近 7 日。日付文字列はゼロ埋めなので辞書順 = 時系列。
    func minDateString(now: Date = Date()) -> String? {
        let daysBack: Int
        switch self {
        case .today: daysBack = 0
        case .days7: daysBack = 6
        case .days30: daysBack = 29
        case .all: return nil
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let from = cal.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: from)
    }

    /// この期間に日付 (YYYY-MM-DD) を含めるか。
    func includes(date: String, now: Date = Date()) -> Bool {
        guard let min = minDateString(now: now) else { return true }
        return date >= min
    }
}
