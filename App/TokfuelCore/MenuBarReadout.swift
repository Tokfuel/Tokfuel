import Foundation

/// メニューバーに常時出す「何を見るか」。「どう見せるか」は MenuBarRepresentation 側。
/// 2 軸に分けているのは、金額・割合・リングを 1 つの enum に混ぜると
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
    /// 月間消費額の算出（retok 32 日走査）が必要な指標か。
    public var showsMonthlyCost: Bool { self == .month || self == .both }
    /// 割合として表せる指標か。プロンプト数は分母を持たない。
    public var supportsRatio: Bool { self != .prompts }
}

/// メニューバーの「どう見せるか」。
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
    /// 分母（基準）が必要な表現か。
    public var needsBasis: Bool { self == .percent || self == .ring || self == .ringAndValue }
    /// 給油機アイコンの代わりにリングを描く表現か。
    public var drawsRing: Bool { self == .ring || self == .ringAndValue }
}

/// ゲージの形。どちらも「消費 / 基準」を面積で示すもので、値の出し方は変わらない。
public enum MenuBarGaugeShape: String, CaseIterable, Identifiable {
    /// 円形のインジケーター。12 時から時計回りに塗る。
    case ring
    /// 給油機アイコンそのものを下から塗り上げる燃料計。
    case tank
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .ring: return "リング"
        case .tank: return "タンク（給油機を下から塗る）"
        }
    }
    /// アイコンと別に描くゲージか。タンクはアイコン自身がゲージなので併記の概念が無い。
    public var isSeparateFromIcon: Bool { self == .ring }
}

/// パーセントとリングが共有する分母。どちらも同じ値の別表現なので基準は 1 つにまとめる。
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

/// 割合・リング表示の素になる「消費」と「基準（分母）」。
/// 基準 0 は「この指標は割合として表せない」を意味する。
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

/// メニューバー表示の組み立てに必要な、設定と集計値のすべて。
/// レベルを外から渡すのは、この組み立てを @MainActor に縛らずテストできるようにするため。
public struct MenuBarInput {
    public var metric: MenuBarMetric = .today
    public var representation: MenuBarRepresentation = .amount
    public var basis: MenuBarPercentBasis = .budgetLimit
    public var shape: MenuBarGaugeShape = .ring
    public var showsRemaining = false
    /// 給油機アイコンを出すか。リングを描くときだけ意味を持つ（リングと入れ替えるのではなく
    /// 横に並べたい人がいる）。リング以外では常にアイコンを出す。
    public var showsIcon = true
    /// ポップオーバーと同じソース表示。並べて表示のとき金額タイトルを Claude / Cursor に分ける。
    public var costSourceMode: CostSourceMode = .combined
    public var prompts = 0
    public var gauge = MenuBarGauge()
    /// 残額表示に使う予算上限（0 なら残額表示なし）。割合の分母とは独立。
    public var dailyLimit: Double = 0
    public var monthlyLimit: Double = 0
    /// Cursor 側の金額が取得できていないか。true のときは 0 円ではなく「—」を出す
    /// （劣化していれば金額は確実に足りないので、0 円と並べると誤情報になる）。
    public var cursorUnavailable = false
    /// 並べて表示用のソース別金額（ゲージの合算とは別に持つ）。
    public var todayClaude: Double = 0
    public var todayCursor: Double = 0
    public var monthClaude: Double = 0
    public var monthCursor: Double = 0
    /// 側ごとの予算レベル。ゲージは側ごとに塗り分けるので、今日だけしきい値を越えたときに
    /// 今日のゲージだけ色が変わる。予算が無い側は nil。
    public var todayLevel: BudgetLevel?
    public var monthLevel: BudgetLevel?
    /// 追従モード中か（TF-0080）。表示する値そのものは変えず、アイコンの明滅にだけ効く。
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

/// ゲージ 1 本ぶんの塗り。
public struct MenuBarGaugeSegment {
    public let fill: Double
    /// その側の予算レベル（予算が無い側は nil）。色はここから決まる。
    public let level: BudgetLevel?
}

/// メニューバーに実際に出す内容。本番（AppDelegate）と設定のライブプレビューが
/// 同じ絵になるよう、両者はこれを共用する。
public struct MenuBarContent {
    /// アイコンの右に並べる文字列（空ならアイコンだけ）。アイコンとの間隔は表示側で足す。
    public var title: String = ""
    public var toolTip: String = ""
    public var shape: MenuBarGaugeShape = .ring
    /// ゲージの塗り（先頭 = 今日）。リングでは先頭が内側。空ならゲージを描かない。
    public var gauges: [MenuBarGaugeSegment] = []
    /// 給油機アイコンを出すか。リングと同時に出すと横並びの 1 枚になる。
    public var showsIcon = true
    /// 給油機アイコン単体の警告色に使うレベル（月・日の悪い方）。
    public var iconLevel: BudgetLevel?
    /// 追従モード中か。アイコンを明滅させるかの判断に使う（描画は MenuBarImage 側）。
    public var isFollowing = false
}

/// メニューバー表示の純粋なロジック。設定値と数値だけを受け取り、実際に描く表現・
/// 塗り分率・文字列を決める。NSImage の描画そのものは MenuBarImage が持つ。
public enum MenuBarReadout {

    /// debug 構成の目印。release と debug のどちらを入れたか分からなくなるのを防ぐ。
    /// リリースビルドでは空文字なので、この分岐は配布物に影響しない。
    public static let debugMarker: String = {
        #if DEBUG
        return "DEBUG"
        #else
        return ""
        #endif
    }()

    /// ツールチップ。debug 構成では目印を前置する（ホバーすればどちらか分かる）。
    public static func buildLabel(_ text: String) -> String {
        debugMarker.isEmpty ? text : "[\(debugMarker)] \(text)"
    }

    /// ウィンドウタイトル。debug 構成では末尾に目印を付ける。
    public static func windowTitle(_ text: String) -> String {
        debugMarker.isEmpty ? text : "\(text)（\(debugMarker)）"
    }

    // MARK: - 旧設定からの移行

    /// v0.x の単一設定 `menuBarDisplay` の rawValue を 2 軸に読み替える。
    /// 新キーが未設定のユーザーだけがここを通る（既存の設定を黙って捨てないため）。
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

    // MARK: - 分母の決定

    /// 基準設定から (消費, 分母) の組を作る。
    ///
    /// 日次平均基準の月側は「平均ペースなら今日までにいくら使っているか」を分母にする。
    /// こうすると今日側・月側のどちらも «実績 ÷ 直近の平均から予測される額» という
    /// 同じ読み方になり、予算未設定でも月のリングが使える。
    ///
    /// 掛ける相手が暦日数ではなく `activeDays`（期間内で実際にコストが出た日数）なのは、
    /// `dailyAverage` が実績のある日だけで割った「稼働 1 日あたり」の額だから。暦日数を
    /// 掛けると、週末に使わない人は平常運転でも 70% 台に見えてしまう。
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

    // MARK: - 表現の解決

    /// パーセント・リングを選べない理由。設定 UI の注記と選択可否が同じ判定から出るようにする。
    public enum RatioUnavailability {
        /// 指標が割合を持たない（プロンプト数）。
        case noRatio
        /// 予算上限を基準にしているが、その指標に必要な上限が未設定。
        case noLimit
    }

    /// パーセント・リング（分母を要る表現）を選べない理由。nil なら選べる。
    ///
    /// 判定に使うのは設定値だけで、非同期に届く集計値は見ない。日次平均は「選ぶと集計が走って
    /// 初めて値が入る」ので、届いていないことを理由に選択肢を塞ぐと永久に選べなくなる。
    /// 実際に描けるかどうかは canRender が集計値を見て判断し、描けなければ金額に落ちる。
    public static func ratioUnavailability(metric: MenuBarMetric, basis: MenuBarPercentBasis,
                                    dailyLimit: Double,
                                    monthlyLimit: Double) -> RatioUnavailability? {
        guard metric.supportsRatio else { return .noRatio }
        guard basis == .budgetLimit else { return nil }
        // 「今日と今月」は両方の上限を要求する（片側だけ欠けた中途半端なリングを出さない）。
        switch metric {
        case .today: return dailyLimit > 0 ? nil : .noLimit
        case .month: return monthlyLimit > 0 ? nil : .noLimit
        case .both: return dailyLimit > 0 && monthlyLimit > 0 ? nil : .noLimit
        case .prompts: return .noRatio
        }
    }

    /// 設定 UI でその表現を選べるか。
    public static func isSelectable(metric: MenuBarMetric, representation: MenuBarRepresentation,
                             basis: MenuBarPercentBasis,
                             dailyLimit: Double, monthlyLimit: Double) -> Bool {
        guard representation.needsBasis else { return true }
        return ratioUnavailability(metric: metric, basis: basis, dailyLimit: dailyLimit,
                                   monthlyLimit: monthlyLimit) == nil
    }

    /// その (指標, 表現) を今の分母で実際に描けるか。
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

    /// 実際に描く表現。分母が無い・プロンプト数指標といった条件では金額表示に落ちる。
    public static func effectiveRepresentation(metric: MenuBarMetric,
                                        representation: MenuBarRepresentation,
                                        gauge: MenuBarGauge) -> MenuBarRepresentation {
        canRender(metric: metric, representation: representation, gauge: gauge)
            ? representation : .amount
    }

    // MARK: - 割合の算出

    /// 消費 ÷ 基準。基準が 0 以下なら nil（割合として意味を持たない）。クランプしない。
    /// 有限でない消費額も nil にして、下流の Int 変換がトラップするのを防ぐ。
    public static func fraction(spend: Double, basis: Double) -> Double? {
        guard basis > 0, spend.isFinite else { return nil }
        return spend / basis
    }

    /// リングの塗り分率（0...1）。100% を超えても満タンで止め、残りモードでは残り分を塗る。
    public static func ringFill(spend: Double, basis: Double, showsRemaining: Bool) -> Double? {
        guard let f = fraction(spend: spend, basis: basis) else { return nil }
        let consumed = min(max(f, 0), 1)
        return showsRemaining ? 1 - consumed : consumed
    }

    /// パーセント文字列。残りモードでは残り率（100 − 消費率）。
    /// リングと違い 100% ではクランプしないので、超過は `142%` / 残りは `-42%` と出る。
    public static func percentText(spend: Double, basis: Double, showsRemaining: Bool) -> String? {
        guard let f = fraction(spend: spend, basis: basis) else { return nil }
        let consumed = (f * 100).rounded()
        let shown = showsRemaining ? 100 - consumed : consumed
        // 極端に小さい基準（上限に 0.0001 を入れた等）で Int 変換が溢れないよう桁を頭打ちにする。
        // 100% でのクランプではなく、あくまでクラッシュ回避のガード。
        return "\(Int(min(max(shown, -999_999), 999_999)))%"
    }

    // MARK: - 表示内容の組み立て

    /// 指標 1 側（今日 / 今月）ぶんの表示素材。
    private struct Side {
        let label: String
        let spend: Double
        let basis: Double
        /// 残額表示に使う予算上限。割合の分母（basis）とは独立。
        let limit: Double
        /// その側の予算レベル。ゲージの色になる。
        let level: BudgetLevel?
        /// 金額を「残 上限 − 消費」で見せるか。
        let showsRemaining: Bool
        /// 割合・ゲージを残り側で見せるか。予算上限を基準にしているときだけ意味を持つ
        /// （「いつもの 1 日に対する残り」という概念は無い）。
        let ratioShowsRemaining: Bool
    }

    /// 指標が扱う側を並べる。プロンプト数は金額の側を持たない。
    /// ラベルは設定ピッカーと同じ文言を使い、表記が二重管理にならないようにする。
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

    /// メニューバーに出す内容。分母を持てない組み合わせは金額表示に落ちる。
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
            // リングが形で伝える値に、桁で読める精度（142% など）を足す関係になる。
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
            // アイコンを外せるのは、アイコンと別にゲージを描くとき（リング）だけ。
            // タンクはアイコン自身がゲージなので外せない。文字だけの表現でも常に出す
            // （数字だけ浮くと何のアプリの値か分からなくなる）。
            showsIcon: drawsGauge && input.shape.isSeparateFromIcon ? input.showsIcon : true,
            iconLevel: [input.todayLevel, input.monthLevel].compactMap { $0 }.max(),
            isFollowing: input.isFollowing)
    }

    /// 金額表示。残額モードかつ上限があれば「残 上限 − 消費」、なければ消費額。
    /// 並べて表示かつ残額 OFF のときは Claude / Cursor を短いラベルで並列する。
    private static func amountText(_ side: Side, input: MenuBarInput) -> String {
        if side.showsRemaining, side.limit > 0 {
            return "残 " + Money.format(side.limit - side.spend)
        }
        if input.costSourceMode == .sideBySide {
            let (claude, cursor) = sideAmounts(side, input: input)
            let cursorText = input.cursorUnavailable ? unavailableText : Money.format(cursor)
            return "Claude \(Money.format(claude)) · Cursor \(cursorText)"
        }
        // 二次ソースだけを見ているときにそれが取れていなければ、金額そのものが不明。
        if input.costSourceMode.showsSingleSecondarySource, input.cursorUnavailable {
            return unavailableText
        }
        return Money.format(side.spend)
    }

    /// 金額・割合が取れなかったことを示す表記。0 円や 0% と紛れない 1 文字にする。
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

    /// ツールチップ 1 側ぶん。リング表現では画面に数字が出ないので、
    /// 金額と（表せるなら）割合の両方をここで伝える。
    private static func toolTip(_ side: Side, input: MenuBarInput) -> String {
        let scope = side.showsRemaining && side.limit > 0 ? "残り予算" : "推定コスト"
        let head = "\(side.label)の\(scope): \(amountText(side, input: input))"
        guard let percent = percentText(side) else { return head }
        return "\(head)（\(percent)）"
    }

    /// 側を横に並べる。2 つ並ぶのは「今日と今月」だけなので、後ろに「月」を添えて
    /// 既存の `$12.34 · 月 $210` の形を保つ。
    private static func joined(_ texts: [String]) -> String {
        guard texts.count == 2 else { return texts.joined(separator: " · ") }
        return "\(texts[0]) · 月 \(texts[1])"
    }
}
