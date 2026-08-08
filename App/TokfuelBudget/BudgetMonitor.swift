import Foundation
import TokfuelCore
import TokfuelSettings
import UserNotifications

/// 予算レベルの判定と、レベルが上がったときの一度きりの通知を担う。
@MainActor
public enum BudgetMonitor {

    public static func periodStart(for period: BudgetPeriod, now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        switch period {
        case .rolling30:
            let start = cal.date(byAdding: .day, value: -29, to: now) ?? now
            return LocalDay.string(from: start, calendar: cal)
        case .calendarMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return LocalDay.string(from: start, calendar: cal)
        }
    }

    public static func periodKey(for period: BudgetPeriod, now: Date = Date()) -> String {
        switch period {
        case .calendarMonth:
            return String(periodStart(for: period, now: now).prefix(7))
        case .rolling30:
            return "rolling"
        }
    }

    public static func level(spend: Double, limit: Double, warnPercent: Int) -> BudgetLevel {
        guard limit > 0 else { return .ok }
        if spend >= limit { return .over }
        if spend >= limit * Double(warnPercent) / 100 { return .warning }
        return .ok
    }

    public enum Kind: String, Sendable {
        case monthly, daily
        public var scopeLabel: String { self == .daily ? "今日の" : "" }
        public var periodLabel: String { self == .daily ? "今日" : "今月" }
    }

    public struct Delivery: Equatable, Sendable {
        public var notification: Bool
        public var alertWindow: Bool
        public var isEmpty: Bool { !notification && !alertWindow }

        public init(notification: Bool, alertWindow: Bool) {
            self.notification = notification
            self.alertWindow = alertWindow
        }
    }

    public struct Message: Equatable, Sendable {
        public var title: String
        public var body: String

        public init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }

    public static func delivery(for style: BudgetAlertStyle,
                                notificationsAvailable: Bool = Self.notificationsAvailable) -> Delivery {
        Delivery(notification: style.usesNotification && notificationsAvailable,
                 alertWindow: style.usesAlertWindow)
    }

    nonisolated public static func percent(spend: Double, limit: Double) -> Int {
        guard limit > 0 else { return 0 }
        return Int(spend / limit * 100)
    }

    public static func message(kind: Kind, level: BudgetLevel, spend: Double, limit: Double) -> Message? {
        let spendStr = Money.format(spend)
        let limitStr = Money.format(limit)
        switch level {
        case .warning:
            return Message(title: "\(kind.scopeLabel)利用額が上限に近づいています",
                           body: "現在 \(spendStr) / 上限 \(limitStr)（\(percent(spend: spend, limit: limit))%）")
        case .over:
            return Message(title: "\(kind.scopeLabel)利用額が上限を超えました",
                           body: "現在 \(spendStr) / 上限 \(limitStr)")
        case .ok:
            return nil
        }
    }

    public static func dailyPeriodKey(now: Date = Date()) -> String {
        LocalDay.string(from: now)
    }

    public static func deliveryIfNeeded(kind: Kind = .monthly, level: BudgetLevel, periodKey: String,
                                        style: BudgetAlertStyle,
                                        notificationsAvailable: Bool = Self.notificationsAvailable,
                                        defaults: UserDefaults = .standard) -> Delivery? {
        let levelKey = kind == .monthly ? "budgetNotifiedLevel" : "budgetNotifiedLevel-daily"
        let periodStoreKey = kind == .monthly ? "budgetNotifiedPeriod" : "budgetNotifiedPeriod-daily"
        let storedPeriod = defaults.string(forKey: periodStoreKey)
        var storedLevel = BudgetLevel(rawValue: defaults.integer(forKey: levelKey)) ?? .ok
        if storedPeriod != periodKey {
            storedLevel = .ok
        }

        if level == .ok {
            defaults.set(BudgetLevel.ok.rawValue, forKey: levelKey)
            defaults.set(periodKey, forKey: periodStoreKey)
            return nil
        }
        guard level > storedLevel else { return nil }

        defaults.set(level.rawValue, forKey: levelKey)
        defaults.set(periodKey, forKey: periodStoreKey)
        return delivery(for: style, notificationsAvailable: notificationsAvailable)
    }

    /// レベルが上がったときに一度だけ通知を送る。アラートウィンドウ用の中身が必要なら返す。
    @discardableResult
    public static func notifyIfNeeded(kind: Kind = .monthly, level: BudgetLevel,
                                      spend: Double, limit: Double, periodKey: String,
                                      style: BudgetAlertStyle) -> BudgetAlertContent? {
        guard let delivery = deliveryIfNeeded(kind: kind, level: level,
                                              periodKey: periodKey, style: style),
              !delivery.isEmpty,
              let message = message(kind: kind, level: level, spend: spend, limit: limit)
        else { return nil }

        if delivery.notification {
            E2EProbe.recordNotification(title: message.title, body: message.body)
            post(kind: kind, level: level, message: message)
        }
        if delivery.alertWindow {
            return BudgetAlertContent(kind: kind, level: level, spend: spend,
                                      limit: limit, message: message)
        }
        return nil
    }

    public static var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
            && Bundle.main.bundlePath.hasSuffix(".app")
            && !Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    public static func requestAuthorizationIfNeeded() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { @Sendable _, _ in }
    }

    private static func post(kind: Kind, level: BudgetLevel, message: Message) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "budget-\(kind.rawValue)-\(level.rawValue)",
                                            content: content, trigger: nil)
        let kindKey = "budget-\(kind.rawValue)"
        UNUserNotificationCenter.current().add(request) { @Sendable error in
            guard error == nil else { return }
            UsageEventLog.shared.log(.notificationShown, meta: ["kind": kindKey])
        }
    }
}
