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

    /// 予算の種類。通知の重複抑止と文面を分ける。
    enum Kind: String {
        case monthly, daily
        var scopeLabel: String { self == .daily ? "今日の" : "" }
    }

    /// 日次予算の期間キー（その日 1 回だけ通知し、日が替わると再アームする）。
    static func dailyPeriodKey(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    /// レベルが前回通知より上がったときだけ通知を送る。
    /// 期間キーが変わる（月・日が替わる等）か、レベルが ok に戻ると再アームする。
    static func notifyIfNeeded(kind: Kind = .monthly, level: BudgetLevel,
                               spend: Double, limit: Double, periodKey: String) {
        // monthly は従来キーを引き継ぎ、通知済み状態を移行後も保つ。
        let levelKey = kind == .monthly ? "budgetNotifiedLevel" : "budgetNotifiedLevel-daily"
        let periodStoreKey = kind == .monthly ? "budgetNotifiedPeriod" : "budgetNotifiedPeriod-daily"
        let defaults = UserDefaults.standard
        let storedPeriod = defaults.string(forKey: periodStoreKey)
        var storedLevel = BudgetLevel(rawValue: defaults.integer(forKey: levelKey)) ?? .ok
        if storedPeriod != periodKey {
            storedLevel = .ok   // 新しい期間なので再アーム
        }

        if level == .ok {
            // 収まったらリセット（次にしきい値を越えたら再通知）
            defaults.set(BudgetLevel.ok.rawValue, forKey: levelKey)
            defaults.set(periodKey, forKey: periodStoreKey)
            return
        }
        guard level > storedLevel else { return }

        defaults.set(level.rawValue, forKey: levelKey)
        defaults.set(periodKey, forKey: periodStoreKey)
        post(kind: kind, level: level, spend: spend, limit: limit)
    }

    /// UNUserNotificationCenter が安全に使える環境かどうか。
    /// - .app バンドル外（swift run 等）では使えない。
    /// - Gatekeeper の App Translocation 中（quarantine 付きのままランダムパスから実行）は
    ///   バンドルプロキシが引けず UNUserNotificationCenter.current() が
    ///   NSInternalInconsistencyException で即クラッシュする（Swift では捕捉不可）。
    ///   その場合は通知だけ静かに諦め、予算バーとアイコン色の警告は生かす。
    private static var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
            && Bundle.main.bundlePath.hasSuffix(".app")
            && !Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    /// 予算機能を有効にしたタイミングで通知許可を求める。
    /// 完了ハンドラはバックグラウンドキューで呼ばれるため、@MainActor 型（BudgetMonitor）の
    /// 文脈で書いても MainActor 隔離と推論されないよう @Sendable を明示する
    /// （推論されると dispatch_assert_queue で即クラッシュする）。
    static func requestAuthorizationIfNeeded() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { @Sendable _, _ in }
    }

    private static func post(kind: Kind, level: BudgetLevel, spend: Double, limit: Double) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        let spendStr = Money.format(spend)
        let limitStr = Money.format(limit)
        switch level {
        case .warning:
            content.title = "\(kind.scopeLabel)Claude 利用額が上限に近づいています"
            content.body = "現在 \(spendStr) / 上限 \(limitStr)（\(Int(spend / limit * 100))%）"
        case .over:
            content.title = "\(kind.scopeLabel)Claude 利用額が上限を超えました"
            content.body = "現在 \(spendStr) / 上限 \(limitStr)"
        case .ok:
            return
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "budget-\(kind.rawValue)-\(level.rawValue)",
                                            content: content, trigger: nil)
        // 掲示に失敗した通知（許可なし等）を「表示した」と数えないよう、成功時だけ記録する。
        // 完了ハンドラはバックグラウンドキューで呼ばれる（上の requestAuthorization と同じ理由で
        // @Sendable 必須）。UsageEventLog はスレッドセーフなので直接呼べる。
        let kindKey = "budget-\(kind.rawValue)"
        UNUserNotificationCenter.current().add(request) { @Sendable error in
            guard error == nil else { return }
            UsageEventLog.shared.log(.notificationShown, meta: ["kind": kindKey])
        }
    }
}
