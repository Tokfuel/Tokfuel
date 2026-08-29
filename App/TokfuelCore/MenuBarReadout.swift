import Foundation

/// 選択肢が掛け算で増え、どれを既定にしても残りが不便になるため。
public enum MenuBarMetric: String, CaseIterable, Identifiable {
    case today, month, both, prompts
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .today: return "今日"
        case .month: return "今月"
        case .both: return "今日と今月"
        case .prompts: return "プロンプト数"
        }
    }
    public var showsMonthlyCost: Bool { self == .month || self == .both }
    public var supportsRatio: Bool { self != .prompts }
}

public enum MenuBarRepresentation: String, CaseIterable, Identifiable {
    case amount, percent, ring, ringAndValue, iconOnly
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .amount: return "金額"
        case .percent: return "パーセント"
        case .ring: return "リング"
        case .ringAndValue: return "リング + パーセント"
        case .iconOnly: return "アイコンのみ"
        }
    }
    public var needsBasis: Bool { self == .percent || self == .ring || self == .ringAndValue }
    public var drawsRing: Bool { self == .ring || self == .ringAndValue }
}

public enum MenuBarGaugeShape: String, CaseIterable, Identifiable {
    case ring
    case tank
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .ring: return "リング"
        case .tank: return "タンク（給油機を下から塗る）"
        }
    }
    public var isSeparateFromIcon: Bool { self == .ring }
}

public enum MenuBarPercentBasis: String, CaseIterable, Identifiable {
    case budgetLimit, dailyAverage30
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .budgetLimit: return "予算上限"
        case .dailyAverage30: return "過去 30 日の日次平均"
        }
    }
    public var note: String {
        switch self {
        case .budgetLimit: return "上限に対する消費率。予算を設定した指標だけで使えます"
        case .dailyAverage30: return "いつもの 1 日と比べた消費率。予算なしでも使えます"
        }
    }
}

public struct MenuBarGauge {
    public var todaySpend: Double = 0
    public var todayBasis: Double = 0
    public var monthSpend: Double = 0
    public var monthBasis: Double = 0

    public init(todaySpend: Double = 0, todayBasis: Double = 0,
                monthSpend: Double = 0, monthBasis: Double = 0) {
        self.todaySpend = todaySpend
        self.todayBasis = todayBasis
        self.monthSpend = monthSpend
        self.monthBasis = monthBasis
    }
}

/// レベルを外から渡すのは、この組み立てを @MainActor に縛らずテストできるようにするため。
public struct MenuBarInput {
    public var metric: MenuBarMetric = .today
    public var representation: MenuBarRepresentation = .amount
    public var basis: MenuBarPercentBasis = .budgetLimit
    public var shape: MenuBarGaugeShape = .ring
    public var showsRemaining = false
    public var showsIcon = true
    public var costSourceMode: CostSourceMode = .combined
    public var prompts = 0
    public var gauge = MenuBarGauge()
    public var dailyLimit: Double = 0
    public var monthlyLimit: Double = 0
    /// Cursor 側の金額が取得できていないか。true のときは 0 円ではなく「—」を出す
    /// （劣化していれば金額は確実に足りないので、0 円と並べると誤情報になる）。
    public var cursorUnavailable = false
    public var todayClaude: Double = 0
    public var todayCursor: Double = 0
    public var monthClaude: Double = 0
    public var monthCursor: Double = 0
    public var todayLevel: BudgetLevel?
    public var monthLevel: BudgetLevel?
    public var isFollowing = false

    public init(
        metric: MenuBarMetric = .today,
        representation: MenuBarRepresentation = .amount,
        basis: MenuBarPercentBasis = .budgetLimit,
        shape: MenuBarGaugeShape = .ring,
        showsRemaining: Bool = false,
        showsIcon: Bool = true,
        costSourceMode: CostSourceMode = .combined,
        prompts: Int = 0,
        gauge: MenuBarGauge = MenuBarGauge(),
        dailyLimit: Double = 0,
        monthlyLimit: Double = 0,
        cursorUnavailable: Bool = false,
        todayClaude: Double = 0,
        todayCursor: Double = 0,
        monthClaude: Double = 0,
        monthCursor: Double = 0,
        todayLevel: BudgetLevel? = nil,
        monthLevel: BudgetLevel? = nil,
        isFollowing: Bool = false
    ) {
        self.metric = metric
        self.representation = representation
        self.basis = basis
        self.shape = shape
        self.showsRemaining = showsRemaining
        self.showsIcon = showsIcon
        self.costSourceMode = costSourceMode
        self.prompts = prompts
        self.gauge = gauge
        self.dailyLimit = dailyLimit
        self.monthlyLimit = monthlyLimit
        self.cursorUnavailable = cursorUnavailable
        self.todayClaude = todayClaude
        self.todayCursor = todayCursor
        self.monthClaude = monthClaude
        self.monthCursor = monthCursor
        self.todayLevel = todayLevel
        self.monthLevel = monthLevel
        self.isFollowing = isFollowing
    }
}

public struct MenuBarGaugeSegment {
    public let fill: Double
    public let level: BudgetLevel?
}

public struct MenuBarContent {
    public var title: String = ""
    public var toolTip: String = ""
    public var shape: MenuBarGaugeShape = .ring
    public var gauges: [MenuBarGaugeSegment] = []
    public var showsIcon = true
    public var iconLevel: BudgetLevel?
    public var isFollowing = false
}

public enum MenuBarReadout {

    public static let debugMarker: String = {
        #if DEBUG
        return "DEBUG"
        #else
        return ""
        #endif
    }()

    public static func buildLabel(_ text: String) -> String {
        debugMarker.isEmpty ? text : "[\(debugMarker)] \(text)"
    }

    public static func windowTitle(_ text: String) -> String {
        debugMarker.isEmpty ? text : "\(text)（\(debugMarker)）"
    }


    /// アイコンのみは指標を持たないので、既定の「今日」を添える。
    public static func migrated(legacy raw: String?) -> (metric: MenuBarMetric,
                                                 representation: MenuBarRepresentation)? {
        switch raw {
        case "cost": return (.today, .amount)
        case "monthlyCost": return (.month, .amount)
        case "bothCosts": return (.both, .amount)
        case "prompts": return (.prompts, .amount)
        case "iconOnly": return (.today, .iconOnly)
        default: return nil
        }
    }


    public static func gauge(basis: MenuBarPercentBasis,
                      todaySpend: Double, monthSpend: Double,
                      dailyLimit: Double, monthlyLimit: Double,
                      dailyAverage: Double, activeDays: Int) -> MenuBarGauge {
        switch basis {
        case .budgetLimit:
            return MenuBarGauge(todaySpend: todaySpend, todayBasis: dailyLimit,
                                monthSpend: monthSpend, monthBasis: monthlyLimit)
        case .dailyAverage30:
            return MenuBarGauge(todaySpend: todaySpend, todayBasis: dailyAverage,
                                monthSpend: monthSpend,
                                monthBasis: dailyAverage * Double(max(activeDays, 1)))
        }
    }


    public enum RatioUnavailability {
        case noRatio
        case noLimit
    }

    /// 月間予算は 32 日集計が届くまで 0 のままなので、届いていないことを理由に選択肢を塞ぐと永久に選べなくなる。
    public static func ratioUnavailability(metric: MenuBarMetric, basis: MenuBarPercentBasis,
                                    dailyLimit: Double,
                                    monthlyLimit: Double) -> RatioUnavailability? {
        guard metric.supportsRatio else { return .noRatio }
        guard basis == .budgetLimit else { return nil }
        switch metric {
        case .today: return dailyLimit > 0 ? nil : .noLimit
        case .month: return monthlyLimit > 0 ? nil : .noLimit
        case .both: return dailyLimit > 0 && monthlyLimit > 0 ? nil : .noLimit
        case .prompts: return .noRatio
        }
    }

    public static func isSelectable(metric: MenuBarMetric, representation: MenuBarRepresentation,
                             basis: MenuBarPercentBasis,
                             dailyLimit: Double, monthlyLimit: Double) -> Bool {
        guard representation.needsBasis else { return true }
        return ratioUnavailability(metric: metric, basis: basis, dailyLimit: dailyLimit,
                                   monthlyLimit: monthlyLimit) == nil
    }

    public static func canRender(metric: MenuBarMetric, representation: MenuBarRepresentation,
                          gauge: MenuBarGauge) -> Bool {
        guard representation.needsBasis else { return true }
        switch metric {
        case .today: return gauge.todayBasis > 0
        case .month: return gauge.monthBasis > 0
        case .both: return gauge.todayBasis > 0 && gauge.monthBasis > 0
        case .prompts: return false   // 分母を持たない（supportsRatio == false）
        }
    }

    public static func effectiveRepresentation(metric: MenuBarMetric,
                                        representation: MenuBarRepresentation,
                                        gauge: MenuBarGauge) -> MenuBarRepresentation {
        canRender(metric: metric, representation: representation, gauge: gauge)
            ? representation : .amount
    }


    public static func fraction(spend: Double, basis: Double) -> Double? {
        guard basis > 0, spend.isFinite else { return nil }
        return spend / basis
    }

    public static func ringFill(spend: Double, basis: Double, showsRemaining: Bool) -> Double? {
        guard let f = fraction(spend: spend, basis: basis) else { return nil }
        let consumed = min(max(f, 0), 1)
        return showsRemaining ? 1 - consumed : consumed
    }

    /// リングと違い 100% ではクランプしないので、超過は `142%` / 残りは `-42%` と出る。
    public static func percentText(spend: Double, basis: Double, showsRemaining: Bool) -> String? {
        guard let f = fraction(spend: spend, basis: basis) else { return nil }
        let consumed = (f * 100).rounded()
        let shown = showsRemaining ? 100 - consumed : consumed
        return "\(Int(min(max(shown, -999_999), 999_999)))%"
    }


    private struct Side {
        let label: String
        let spend: Double
        let basis: Double
        let limit: Double
        let level: BudgetLevel?
        let showsRemaining: Bool
        let ratioShowsRemaining: Bool
    }

    private static func sides(of input: MenuBarInput) -> [Side] {
        let ratioRemaining = input.showsRemaining && input.basis == .budgetLimit
        let today = Side(label: MenuBarMetric.today.label, spend: input.gauge.todaySpend,
                         basis: input.gauge.todayBasis, limit: input.dailyLimit,
                         level: input.todayLevel, showsRemaining: input.showsRemaining,
                         ratioShowsRemaining: ratioRemaining)
        let month = Side(label: MenuBarMetric.month.label, spend: input.gauge.monthSpend,
                         basis: input.gauge.monthBasis, limit: input.monthlyLimit,
                         level: input.monthLevel, showsRemaining: input.showsRemaining,
                         ratioShowsRemaining: ratioRemaining)
        switch input.metric {
        case .today: return [today]
        case .month: return [month]
        case .both: return [today, month]
        case .prompts: return []
        }
    }

    public static func content(for input: MenuBarInput) -> MenuBarContent {
        let representation = effectiveRepresentation(
            metric: input.metric, representation: input.representation, gauge: input.gauge)
        guard representation != .iconOnly else {
            return MenuBarContent(toolTip: buildLabel("Tokfuel"), isFollowing: input.isFollowing)
        }
        let sides = sides(of: input)
        guard !sides.isEmpty else {
            return MenuBarContent(title: "\(input.prompts)",
                                  toolTip: buildLabel("今日のプロンプト数: \(input.prompts)"),
                                  isFollowing: input.isFollowing)
        }

        let title: String
        switch representation {
        case .ring:
            title = ""   // リングだけで割合を示す
        case .percent, .ringAndValue:
            // リングは割合のインジケーターなので、添える数値も割合にそろえる。
            // 取れていない二次ソースだけを見ているときは 0% ではなく「—」（0% は誤情報）。
            title = input.costSourceMode.showsSingleSecondarySource && input.cursorUnavailable
                ? unavailableText
                : joined(sides.compactMap(percentText))
        default:
            title = joined(sides.map { amountText($0, input: input) })
        }
        let drawsGauge = representation.drawsRing
        return MenuBarContent(
            title: title,
            toolTip: buildLabel(sides.map { toolTip($0, input: input) }.joined(separator: " / ")),
            shape: input.shape,
            gauges: drawsGauge
                ? sides.map { MenuBarGaugeSegment(fill: ringFill($0), level: $0.level) } : [],
            showsIcon: drawsGauge && input.shape.isSeparateFromIcon ? input.showsIcon : true,
            iconLevel: [input.todayLevel, input.monthLevel].compactMap { $0 }.max(),
            isFollowing: input.isFollowing)
    }

    private static func amountText(_ side: Side, input: MenuBarInput) -> String {
        if side.showsRemaining, side.limit > 0 {
            return "残 " + Money.format(side.limit - side.spend)
        }
        if input.costSourceMode == .sideBySide {
            let (claude, cursor) = sideAmounts(side, input: input)
            let cursorText = input.cursorUnavailable ? unavailableText : Money.format(cursor)
            return "Claude \(Money.format(claude)) · Cursor \(cursorText)"
        }
        if input.costSourceMode.showsSingleSecondarySource, input.cursorUnavailable {
            return unavailableText
        }
        return Money.format(side.spend)
    }

    public static let unavailableText = "—"

    private static func sideAmounts(_ side: Side, input: MenuBarInput) -> (Double, Double) {
        // Side に今日/月の区別が無いのでラベルで分ける（sides が付けるラベルと一致）。
        if side.label == MenuBarMetric.month.label {
            return (input.monthClaude, input.monthCursor)
        }
        return (input.todayClaude, input.todayCursor)
    }

    private static func percentText(_ side: Side) -> String? {
        percentText(spend: side.spend, basis: side.basis,
                    showsRemaining: side.ratioShowsRemaining)
    }

    private static func ringFill(_ side: Side) -> Double {
        ringFill(spend: side.spend, basis: side.basis,
                 showsRemaining: side.ratioShowsRemaining) ?? 0
    }

    /// リング表現では画面に数字が出ないので、ツールチップに割合を添える。
    private static func toolTip(_ side: Side, input: MenuBarInput) -> String {
        let scope = side.showsRemaining && side.limit > 0 ? "残り予算" : "推定コスト"
        let head = "\(side.label)の\(scope): \(amountText(side, input: input))"
        guard let percent = percentText(side) else { return head }
        return "\(head)（\(percent)）"
    }

    /// 2 つ並ぶのは「今日と今月」だけなので、後ろに「月」を添えて区別する。
    private static func joined(_ texts: [String]) -> String {
        guard texts.count == 2 else { return texts.joined(separator: " · ") }
        return "\(texts[0]) · 月 \(texts[1])"
    }
}
