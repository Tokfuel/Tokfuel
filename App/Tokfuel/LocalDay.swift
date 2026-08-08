import Foundation

/// ローカル暦日の保存形式（YYYY-MM-DD）を一元管理する。
enum LocalDay {
    nonisolated static func string(
        from date: Date,
        calendar source: Calendar = .current
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    nonisolated static func date(
        from value: String,
        calendar source: Calendar = .current
    ) -> Date? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ),
        string(from: date, calendar: calendar) == value else { return nil }
        return date
    }
}
