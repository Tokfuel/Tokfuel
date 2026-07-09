import Foundation
import UserNotifications

/// 予算に対する現在の消費レベル。
enum BudgetLevel: Int, Comparable {
    case ok = 0        // しきい値未満
    case warning = 1   // しきい値以上・上限未満
    case over = 2      // 上限超過

    static func < (lhs: BudgetLevel, rhs: BudgetLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 予算レベルの判定と、レベルが上がったときの一度きりの通知を担う。
@MainActor
enum BudgetMonitor {

    /// 期間の開始日 (YYYY-MM-DD)。この日以降の daily コストを合算する。
    static func periodStart(for period: BudgetPeriod, now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        switch period {
        case .rolling30:
            let start = cal.date(byAdding: .day, value: -29, to: now) ?? now
            return f.string(from: start)
        case .calendarMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return f.string(from: start)
        }
    }

    /// 通知の重複抑止に使う期間キー。暦月は月が替わると、ローリングは日が進むと再アームする。
    static func periodKey(for period: BudgetPeriod, now: Date = Date()) -> String {
        switch period {
        case .calendarMonth:
            return String(periodStart(for: period, now: now).prefix(7))   // "2026-07"
        case .rolling30:
            return "rolling"
        }
    }

    static func level(spend: Double, limit: Double, warnPercent: Int) -> BudgetLevel {
        guard limit > 0 else { return .ok }
        if spend >= limit { return .over }
        if spend >= limit * Double(warnPercent) / 100 { return .warning }
        return .ok
    }

    // MARK: - 通知

    private static let notifiedLevelKey = "budgetNotifiedLevel"
    private static let notifiedPeriodKey = "budgetNotifiedPeriod"

    /// レベルが前回通知より上がったときだけ通知を送る。
    /// 期間キーが変わる（月が替わる等）か、レベルが ok に戻ると再アームする。
    static func notifyIfNeeded(level: BudgetLevel, spend: Double, limit: Double,
                               periodKey: String) {
        let defaults = UserDefaults.standard
        let storedPeriod = defaults.string(forKey: notifiedPeriodKey)
        var storedLevel = BudgetLevel(rawValue: defaults.integer(forKey: notifiedLevelKey)) ?? .ok
        if storedPeriod != periodKey {
            storedLevel = .ok   // 新しい期間なので再アーム
        }

        if level == .ok {
            // 収まったらリセット（次にしきい値を越えたら再通知）
            defaults.set(BudgetLevel.ok.rawValue, forKey: notifiedLevelKey)
            defaults.set(periodKey, forKey: notifiedPeriodKey)
            return
        }
        guard level > storedLevel else { return }

        defaults.set(level.rawValue, forKey: notifiedLevelKey)
        defaults.set(periodKey, forKey: notifiedPeriodKey)
        post(level: level, spend: spend, limit: limit)
    }

    /// UNUserNotificationCenter は .app バンドル外（swift run 等）だと使えないため確認する。
    private static var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// 予算機能を有効にしたタイミングで通知許可を求める。
    static func requestAuthorizationIfNeeded() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func post(level: BudgetLevel, spend: Double, limit: Double) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        let spendStr = String(format: "$%.2f", spend)
        let limitStr = String(format: "$%.0f", limit)
        switch level {
        case .warning:
            content.title = "Claude 利用額が上限に近づいています"
            content.body = "現在 \(spendStr) / 上限 \(limitStr)（\(Int(spend / limit * 100))%）"
        case .over:
            content.title = "Claude 利用額が上限を超えました"
            content.body = "現在 \(spendStr) / 上限 \(limitStr)"
        case .ok:
            return
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "budget-\(level.rawValue)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
