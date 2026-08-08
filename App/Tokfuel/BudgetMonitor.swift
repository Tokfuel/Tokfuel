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
    enum Kind: String, Sendable {
        case monthly, daily
        var scopeLabel: String { self == .daily ? "今日の" : "" }
        /// アラートウィンドウの見出しに出す期間の呼び名。
        var periodLabel: String { self == .daily ? "今日" : "今月" }
    }

    /// 実際に使う知らせ手段。ユーザーの選択（`BudgetAlertStyle`）と実行環境から決まる。
    struct Delivery: Equatable, Sendable {
        var notification: Bool
        var alertWindow: Bool
        var isEmpty: Bool { !notification && !alertWindow }
    }

    /// 通知とアラートウィンドウが共有する文面。
    struct Message: Equatable, Sendable {
        var title: String
        var body: String
    }

    /// 選んだ手段と実行環境から、実際に使う手段を決める。
    ///
    /// 通知は `.app` バンドル外や App Translocation 中には出せないので落とす。アラート
    /// ウィンドウにはその制約がないが、`notification` を選んだ人の挙動を黙って変えないため、
    /// ウィンドウでの代替は `alert` / `both` を選んでいるときだけにする。
    static func delivery(for style: BudgetAlertStyle,
                         notificationsAvailable: Bool = Self.notificationsAvailable) -> Delivery {
        Delivery(notification: style.usesNotification && notificationsAvailable,
                 alertWindow: style.usesAlertWindow)
    }

    /// 上限に対する割合 (%)。上限 0 のときは 0（その場合レベルは .ok なので実際には使わない）。
    nonisolated static func percent(spend: Double, limit: Double) -> Int {
        guard limit > 0 else { return 0 }
        return Int(spend / limit * 100)
    }

    /// レベルに応じた文面。知らせる場面でないとき（.ok）は nil。
    static func message(kind: Kind, level: BudgetLevel, spend: Double, limit: Double) -> Message? {
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

    /// 日次予算の期間キー（その日 1 回だけ通知し、日が替わると再アームする）。
    static func dailyPeriodKey(now: Date = Date()) -> String {
        LocalDay.string(from: now)
    }

    /// レベルが前回より上がったときだけ、使う手段を返す（重複抑止の状態もここで進める）。
    /// 期間キーが変わる（月・日が替わる等）か、レベルが ok に戻ると再アームする。
    ///
    /// 掲示そのものは行わないので、ウィンドウサーバのないテストからも安全に呼べる。
    /// どの手段で知らせるかは `style` で受け取り、ここから `AppSettings` や `UserDefaults` の
    /// 設定値は読まない（`warnPercent` と同じ流儀）。
    /// - Returns: 知らせるべきときはその手段。抑止したときは nil。手段が両方 false の
    ///   `Delivery` は「知らせる場面だが、この環境で出せる手段がない」を表す。
    static func deliveryIfNeeded(kind: Kind = .monthly, level: BudgetLevel, periodKey: String,
                                 style: BudgetAlertStyle,
                                 notificationsAvailable: Bool = Self.notificationsAvailable,
                                 defaults: UserDefaults = .standard) -> Delivery? {
        // monthly は従来キーを引き継ぎ、通知済み状態を移行後も保つ。
        let levelKey = kind == .monthly ? "budgetNotifiedLevel" : "budgetNotifiedLevel-daily"
        let periodStoreKey = kind == .monthly ? "budgetNotifiedPeriod" : "budgetNotifiedPeriod-daily"
        let storedPeriod = defaults.string(forKey: periodStoreKey)
        var storedLevel = BudgetLevel(rawValue: defaults.integer(forKey: levelKey)) ?? .ok
        if storedPeriod != periodKey {
            storedLevel = .ok   // 新しい期間なので再アーム
        }

        if level == .ok {
            // 収まったらリセット（次にしきい値を越えたら再通知）
            defaults.set(BudgetLevel.ok.rawValue, forKey: levelKey)
            defaults.set(periodKey, forKey: periodStoreKey)
            return nil
        }
        guard level > storedLevel else { return nil }

        defaults.set(level.rawValue, forKey: levelKey)
        defaults.set(periodKey, forKey: periodStoreKey)
        return delivery(for: style, notificationsAvailable: notificationsAvailable)
    }

    /// レベルが上がったときに一度だけ、選ばれた手段で知らせる。アプリからの入口。
    /// - Parameter onOpenSettings: アラートウィンドウの「予算設定を開く」から呼ばれる。
    static func notifyIfNeeded(kind: Kind = .monthly, level: BudgetLevel,
                               spend: Double, limit: Double, periodKey: String,
                               style: BudgetAlertStyle,
                               onOpenSettings: @escaping () -> Void = {}) {
        guard let delivery = deliveryIfNeeded(kind: kind, level: level,
                                              periodKey: periodKey, style: style),
              !delivery.isEmpty,
              let message = message(kind: kind, level: level, spend: spend, limit: limit)
        else { return }

        if delivery.notification {
            post(kind: kind, level: level, message: message)
        }
        if delivery.alertWindow {
            BudgetAlertWindow.shared.show(
                BudgetAlertContent(kind: kind, level: level, spend: spend,
                                   limit: limit, message: message),
                onOpenSettings: onOpenSettings)
        }
    }

    /// UNUserNotificationCenter が安全に使える環境かどうか。
    /// - .app バンドル外（swift run 等）では使えない。
    /// - Gatekeeper の App Translocation 中（quarantine 付きのままランダムパスから実行）は
    ///   バンドルプロキシが引けず UNUserNotificationCenter.current() が
    ///   NSInternalInconsistencyException で即クラッシュする（Swift では捕捉不可）。
    ///   その場合は通知だけ静かに諦め、予算バーとアイコン色の警告は生かす。
    static var notificationsAvailable: Bool {
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

    private static func post(kind: Kind, level: BudgetLevel, message: Message) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
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
