import AppKit
import SwiftUI
import Charts
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

public struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var settings: AppSettings
    // private ではない — ScreenshotRenderer がフッターのアップデートボタンをプレビュー
    // させるために、フィクスチャの UpdateChecker を渡せるようにする。
    @ObservedObject var updater: UpdateChecker
    public var onOpenSettings: () -> Void = {}
    public var onOpenAbout: () -> Void = {}
    public var initiallyExpandsAdvice = false

    public init(
        store: UsageStore,
        settings: AppSettings = .shared,
        updater: UpdateChecker = .shared,
        onOpenSettings: @escaping () -> Void = {},
        onOpenAbout: @escaping () -> Void = {},
        initiallyExpandsAdvice: Bool = false
    ) {
        self.store = store
        self.settings = settings
        self.updater = updater
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
        self.initiallyExpandsAdvice = initiallyExpandsAdvice
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    budgetSection
                    if let report = store.report {
                        chartSection(report)
                        modelBreakdown(report)
                        topSessionsSection(report)
                        // ソースの選択による絞り込みは store 側の合成に任せる。
                        adviceSection(report)
                    } else if store.retokError == nil {
                        loadingSection
                    }
                    errorSection
                }
                .padding(16)
            }
            Divider()
            footerBar
        }
        .frame(width: 360, height: 520)
        .onAppear {
            UsageEventLog.shared.log(.tabOpen, meta: ["tab": "cost"])
            if store.awaitingSignInRecheck {
                store.awaitingSignInRecheck = false
                store.reloadReport()
            }
        }
    }


    private var heroSection: some View {
        let mode = settings.costSourceMode
        return VStack(alignment: .leading, spacing: 2) {
            Text("今日")
                .font(.caption)
                .foregroundStyle(.secondary)
            // 取れなかったぶんだけで作った 0 円は誤情報なので、金額ではなく「—」を出す
            // （Cursor のみのモードで Cursor が劣化したときに起きる）。
            Text(store.todayCostUnavailable ? "—" : Self.money(store.todayCost))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            // 並べて表示はヒーローを分割せず、内訳キャプション 1 行が担う。0 円のソースは載せない
            // （"その他" のような曖昧なまとめラベルにしない）。
            if mode == .sideBySide {
                Text(Self.sideBySideCaption(
                    claudeCost: store.todayCost(forSource: CostSourceMode.claudeSourceID),
                    driverBreakdown: store.driverBreakdown,
                    unknownSources: store.unknownSourceNames))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if mode == .cursorOnly {
                Text("Cursor（推定）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            sourceWarnings
        }
    }

    /// 二次ソースの取得が劣化しているときの注意書き。$0 を「今日は使っていない」と誤読させない
    /// ため、フッター側のエラー行（retok 専用）ではなく金額のすぐ下に出す。
    /// サインインし直せば直る劣化には、そのアプリを前面に出すボタンを添える——Tokfuel 自身は
    /// ログイン画面を持たないので、サインインは本家アプリにそのまま任せる。
    @ViewBuilder
    private var sourceWarnings: some View {
        ForEach(store.degradedSourceWarnings) { warning in
            VStack(alignment: .leading, spacing: 6) {
                Label("\(warning.name): \(warning.message)",
                      systemImage: "exclamationmark.triangle")
                if let bundleID = warning.signInBundleID {
                    // そのままラベルにする——押しても Tokfuel はサインインを代行しない。
                    Button("\(warning.name) を開く") {
                        store.awaitingSignInRecheck = true
                        Self.activateApp(bundleID: bundleID)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Self.warningTint)
                    .foregroundStyle(.primary)
                }
            }
            .font(.caption)
            .foregroundStyle(Self.warningTint)
            .padding(.top, 6)
        }
    }

    /// 注意書き（アイコンと文字）の色。金額の下でオレンジは予算ゲージの警告色と紛れるので、
    /// 「取れていない」ことを言い切る赤にする。外観に合わせて振るのは、暗い側で映える明度が
    /// そのままライト側ではコントラスト不足になるため。
    public static let warningTint = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.00, green: 0.30, blue: 0.24, alpha: 1)
            : NSColor(srgbRed: 0.82, green: 0.10, blue: 0.06, alpha: 1)
    })

    public static let chromeTint = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .secondaryLabelColor
            : .tertiaryLabelColor
    })

    /// 指定アプリを前面に出す。見つからなければ何もしない（アンインストール直後など）。
    /// サインインの完了は監視しない——10 分ごとの定期更新か、次にポップオーバーを開いた
    /// ときの再取得が新しいトークンを拾う。
    public static func activateApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// 0 円のソースは載せない（"その他" のような曖昧なまとめラベルにしない）。
    /// 取得できなかったソースは 0 円として並べず「—」にする——0 円と「不明」は別の情報。
    public static func sideBySideCaption(claudeCost: Double,
                                  driverBreakdown: [(name: String, cost: Double)],
                                  unknownSources: [String] = []) -> String {
        var parts = ["\(UsageStore.claudeSourceLabel) \(money(claudeCost))"]
        parts += driverBreakdown.filter { $0.cost > 0 }.map { "\($0.name) \(money($0.cost))" }
        parts += unknownSources.map { "\($0) —" }
        return parts.joined(separator: " · ")
    }


    /// 並べて表示でもゲージの分母は合算（設定した上限との近さを見るため）。
    @ViewBuilder
    private var budgetSection: some View {
        if settings.dailyBudgetLimit > 0 {
            BudgetRow(title: "予算 (今日)", spend: store.todayCost, limit: settings.dailyBudgetLimitUSD,
                      level: store.dailyBudgetLevel ?? .ok,
                      warnPercent: settings.budgetWarnPercent)
        }
        if settings.budgetLimit > 0 {
            BudgetRow(title: "予算 (\(settings.budgetPeriod == .calendarMonth ? "今月" : "30日"))",
                      spend: store.budgetSpend, limit: settings.budgetLimitUSD,
                      level: store.budgetLevel ?? .ok,
                      warnPercent: settings.budgetWarnPercent)
        }
    }


    private func chartSection(_ report: RetokReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("推移")
                Picker("", selection: chartStyleSelection) {
                    Image(systemName: "chart.bar.xaxis").tag(CostChartStyle.daily)
                    Image(systemName: "chart.xyaxis.line").tag(CostChartStyle.cumulative)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 70)
                .labelsHidden()
                Spacer()
                Picker("", selection: reportPeriodSelection) {
                    ForEach(ReportPeriod.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 200)
                .labelsHidden()
            }
            Group {
                switch store.costChartStyle {
                case .daily: dailyChart(report)
                case .cumulative: cumulativeChart(report)
                }
            }
            // 色と線は情報を持つときだけ使う。
            .chartXAxis {
                let period = store.reportPeriod
                AxisMarks(values: xAxisValues(report)) { value in
                    AxisValueLabel {
                        if let short = value.as(String.self) {
                            Text(verbatim: Self.xAxisLabel(short, period: period))
                                .font(.caption2)
                        }
                    }
                }
            }
            // 系列を表示通貨建てで描くので、automatic の目盛りも円なら 0 / 500 / 1000
            // のようにきれいな整数になる（USD 目盛りをラベルだけ換算すると端数が残る）。
            .chartYAxis {
                let currency = settings.displayCurrency
                let rate = Money.currentRate()
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(verbatim: Money.formatAxis(v, currency: currency, rate: rate))
                                .font(.caption2)
                        }
                    }
                }
            }
            .id(settings.displayCurrency)
            .frame(height: 110)
            // 再解析中も前回の絵を隠さない。右下の小さなインジケーターだけで進行を示す。
            .overlay(alignment: .bottomTrailing) {
                if store.isReportLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(2)
                }
            }
            chartCaption(report)
        }
    }

    private func dailyChart(_ report: RetokReport) -> some View {
        let rows = store.chartRows(for: report)
        let showsLegend = Set(rows.map(\.source)).count > 1
        return Chart(rows, id: \.id) { row in
            BarMark(
                x: .value("Date", shortDate(row.date)),
                y: .value("Cost", chartAmount(row.cost))
            )
            .foregroundStyle(by: .value("Source", row.source))
            .cornerRadius(2)
        }
        .chartForegroundStyleScale([
            UsageStore.claudeSourceLabel: Color.accentColor,
            "Cursor": Color.secondary,
            "Codex": Color.purple
        ])
        .chartLegend(showsLegend ? .visible : .hidden)
    }

    /// 上限の参照線を破線で添える — ずれた期間に線を引くと嘘になる。
    private func cumulativeChart(_ report: RetokReport) -> some View {
        let points = UsageStore.cumulativeRows(
            from: store.chartRows(for: report),
            over: UsageStore.windowDates(days: report.periodDays))
        return Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", shortDate(point.date)),
                    y: .value("Cost", chartAmount(point.total))
                )
            }
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            if case let .referenceLine(limit) = store.cumulativeBudgetAnnotation {
                RuleMark(y: .value("Cost", chartAmount(limit)))
                    .foregroundStyle(.tertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    // プロット領域の外へはみ出すと金額軸や余白に食い込むため、チャート内に収める。
                    .annotation(position: .topLeading,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        Text("予算 \(Self.money(limit))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }

    private func chartAmount(_ usd: Double) -> Double {
        Money.displayAmount(
            forUSD: usd,
            currency: settings.displayCurrency,
            rate: Money.currentRate())
    }

    private func chartCaption(_ report: RetokReport) -> some View {
        var parts = ["合計 \(Self.money(store.periodTotalCost(for: report)))"]
        if settings.costSourceMode.includes(sourceID: CostSourceMode.claudeSourceID),
           report.totals.prompts > 0 {
            parts.append("プロンプト単価 "
                         + Self.money(report.totals.cost / Double(report.totals.prompts)))
        }
        if store.costChartStyle == .cumulative,
           case let .monthEndProjection(amount) = store.cumulativeBudgetAnnotation {
            parts.append("月末 約\(Self.money(amount))")
        }
        return Text(parts.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    @ViewBuilder
    private func modelBreakdown(_ report: RetokReport) -> some View {
        let rows = store.modelCostRows(for: report)
        if !rows.isEmpty {
            let maxCost = rows.map(\.cost).max() ?? 1
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("モデル別")
                ForEach(rows) { row in
                    if let source = row.source,
                       row.id == rows.first(where: { $0.source == source })?.id {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, source == rows.first?.source ? 0 : 4)
                    }
                    HStack(spacing: 8) {
                        Text(shortModel(row.model))
                            .font(.caption)
                            .lineLimit(1)
                            .frame(width: 100, alignment: .leading)
                        MeterBar(fraction: row.cost / maxCost, color: .secondary.opacity(0.45))
                        Text(Self.money(row.cost))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topSessionsSection(_ report: RetokReport) -> some View {
        let rows = store.topSessionRows(for: report)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("高コストのセッション")
                ForEach(rows) { row in
                    HStack(spacing: 6) {
                        Text(row.title)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(row.isEstimated ? "\(row.source)（推定）" : row.source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .fixedSize()
                        Spacer(minLength: 4)
                        Text(Self.money(row.cost))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func adviceSection(_ report: RetokReport) -> some View {
        let items = store.adviceItems(for: report)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("節約のヒント")
                ForEach(items) { item in
                    AdviceRow(advice: item.advice, source: item.source,
                              initiallyExpanded: initiallyExpandsAdvice)
                }
            }
        }
    }


    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView("解析中…")
                .controlSize(.small)
            Spacer()
        }
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = store.retokError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }


    private var footerBar: some View {
        HStack {
            if let date = store.lastUpdated {
                Text("更新 \(date, style: .time)")
                    .font(.caption)
                    .foregroundStyle(Self.chromeTint)
            }
            #if DEBUG
            Text(MenuBarReadout.debugMarker)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.orange, in: Capsule())
                .help("開発用の debug 構成です（設定の一番下にデバッグ項目があります）")
            #endif
            Spacer()
            updateFooterButton
            Menu {
                Button("再読み込み") { store.reload() }
                Divider()
                Button("CSV を書き出す（日別）") {
                    if let report = store.report {
                        CSVExportService.presentSavePanel(report: report,
                                                          periodLabel: store.reportPeriod.label,
                                                          granularity: .daily)
                    }
                }
                .disabled(store.report == nil)
                Button("CSV を書き出す（月別）") {
                    if let report = store.report {
                        CSVExportService.presentSavePanel(report: report,
                                                          periodLabel: store.reportPeriod.label,
                                                          granularity: .monthly)
                    }
                }
                .disabled(store.report == nil)
                Divider()
                Button("設定") { onOpenSettings() }
                Button("Tokfuel について") { onOpenAbout() }
                Divider()
                Button("Tokfuel を終了") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            // borderlessButton のラベルはティントで塗られるので、
            // tertiary はダークで背景に溶けやすいので、外観に合わせて一段上げる。
            .tint(Self.chromeTint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var updateFooterButton: some View {
        if let update = updater.available {
            let skipHint = "（右クリックでこのバージョンをスキップ）"
            Group {
                switch updater.phase {
                case .working:
                    ProgressView()
                        .controlSize(.mini)
                        .help("更新中…" + skipHint)
                case .failed(let message):
                    Button {
                        updater.installOffered()
                    } label: {
                        Label("再試行", systemImage: "exclamationmark.triangle.fill")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .help(message + skipHint)
                case .idle:
                    Button {
                        updater.installOffered()
                    } label: {
                        Text(updater.installsInPlace ? "アップデート" : "リリースページを開く")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("v\(update.version) が利用可能です" + skipHint)
                }
            }
            .contextMenu {
                Button("このバージョンをスキップ") { updater.skipOffered() }
            }
            .padding(.trailing, 4)
        }
    }


    private func sectionHeader(_ title: String, badge: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let badge {
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    /// period_change として誤記録しないよう、ピッカー操作のときだけ記録する。
    private var reportPeriodSelection: Binding<ReportPeriod> {
        Binding(get: { store.reportPeriod },
                set: { period in
                    store.reportPeriod = period
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost", "period": period.rawValue])
                })
    }

    private var chartStyleSelection: Binding<CostChartStyle> {
        Binding(get: { store.costChartStyle },
                set: { style in
                    store.costChartStyle = style
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost-style", "style": style.rawValue])
                })
    }

    private func xAxisValues(_ report: RetokReport) -> [String] {
        let dates: [String]
        switch store.costChartStyle {
        case .cumulative:
            // 累積は窓の全日がカテゴリになるので、ラベル候補も窓に合わせる。
            dates = UsageStore.windowDates(days: report.periodDays)
        case .daily:
            let fromRows = Array(Set(store.chartRows(for: report).map(\.date))).sorted()
            if fromRows.isEmpty {
                let from = UsageStore.reportWindowStart(days: report.periodDays)
                dates = report.dailySorted.map(\.date).filter { $0 >= from }
            } else {
                dates = fromRows
            }
        }
        return Self.xAxisShortDates(
            fromISODates: dates,
            period: store.reportPeriod,
            weekStart: settings.weekStart.weekday)
    }

    public nonisolated static func xAxisShortDates(
        fromISODates dates: [String],
        period: ReportPeriod,
        weekStart: Int
    ) -> [String] {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        switch period {
        case .today, .thisWeek:
            return dates.map(shortDate)
        case .thisMonth:
            guard dates.count > 10 else { return dates.map(shortDate) }
            return dates.filter { iso in
                guard let date = f.date(from: iso) else { return false }
                return Calendar.current.component(.weekday, from: date) == weekStart
            }.map(shortDate)
        case .thisYear:
            let monthStarts = dates.filter { iso in
                guard let date = f.date(from: iso) else { return false }
                return Calendar.current.component(.day, from: date) == 1
            }
            let picks = monthStarts.isEmpty
                ? evenlySpaced(dates, maxCount: 6)
                : evenlySpaced(monthStarts, maxCount: 6)
            return picks.map(shortDate)
        }
    }

    public nonisolated static func xAxisLabel(_ shortDate: String, period: ReportPeriod) -> String {
        guard period == .thisYear else { return shortDate }
        let parts = shortDate.split(separator: "/")
        guard let month = parts.first.flatMap({ Int($0) }) else { return shortDate }
        return "\(month)月"
    }

    public nonisolated static func evenlySpaced(_ items: [String], maxCount: Int) -> [String] {
        guard maxCount > 0, !items.isEmpty else { return [] }
        guard items.count > maxCount, maxCount > 1 else { return items }
        var result: [String] = []
        var seen = Set<Int>()
        for i in 0..<maxCount {
            let index = Int((Double(i) * Double(items.count - 1)
                             / Double(maxCount - 1)).rounded())
            if seen.insert(index).inserted {
                result.append(items[index])
            }
        }
        return result
    }

    private func shortDate(_ date: String) -> String {
        Self.shortDate(date)
    }

    public nonisolated static func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        return parts.count == 3 ? "\(parts[1])/\(parts[2])" : date
    }

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20251001", with: "")
    }

    public nonisolated static func money(_ value: Double) -> String {
        Money.format(value)
    }
}

public struct BudgetRow: View {
    public let title: String
    public let spend: Double
    public let limit: Double
    public let level: BudgetLevel
    public let warnPercent: Int

    private var color: Color {
        switch level {
        case .over: return .red
        case .warning: return .orange
        case .ok: return .secondary.opacity(0.45)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                trailingStatus
                    .font(.caption.monospacedDigit())
            }
            MeterBar(fraction: spend / limit,
                     marker: Double(warnPercent) / 100,
                     color: color)
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch level {
        case .ok:
            Text("\(PopoverView.money(spend)) / \(PopoverView.money(limit))")
                .foregroundStyle(.secondary)
        case .warning:
            Text("残り \(PopoverView.money(limit - spend))")
                .foregroundStyle(.orange)
        case .over:
            Label("超過 \(PopoverView.money(spend - limit))",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

public struct MeterBar: View {
    public let fraction: Double
    public var marker: Double? = nil
    public var color: Color = .accentColor

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color)
                    .frame(width: max(3, geo.size.width * min(max(fraction, 0), 1)))
                if let marker {
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 1)
                        .offset(x: geo.size.width * marker)
                }
            }
        }
        .frame(height: 6)
    }
}

/// 出どころ（Claude / Cursor）はバッジで示す — 同じリストに 2 系統が並ぶので、
/// どちらを見て言っているのかが分からないとヒントを判断に使えない。
public struct AdviceRow: View {
    public let advice: RetokReport.Advice
    public let source: String
    @State private var isExpanded: Bool
    @State private var didCopy = false

    public init(advice: RetokReport.Advice, source: String, initiallyExpanded: Bool = false) {
        self.advice = advice
        self.source = source
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var color: Color {
        switch advice.severity {
        case "high": return .red
        case "medium", "warn": return .orange
        default: return .secondary.opacity(0.8)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // キーボードフォーカスと押下のセマンティクスが要るため——タップでしか開けないと、
            // キーボード利用者は展開の中にあるコピーボタンに到達できない。
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)
            .accessibilityLabel(advice.title)
            .accessibilityHint(isExpanded ? "閉じる" : "詳細を開く")
            if isExpanded {
                Text(advice.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                copyButton
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: advice.severity == "high"
                  ? "exclamationmark.triangle.fill" : "lightbulb")
                .font(.caption)
                .foregroundStyle(color)
            Text(source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
                .fixedSize()
            Text(advice.title)
                .font(.caption)
                .lineLimit(isExpanded ? nil : 1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }

    private var copyButton: some View {
        HStack {
            Spacer()
            Button {
                copyPrompt()
            } label: {
                // 「プロンプトをコピー」だとヒント本文の複製と読めるので、
                // 何のためのプロンプトなのかをラベルで言い切る。
                Label(didCopy ? "コピーしました" : "改善プロンプトをコピー",
                      systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(didCopy ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .help("この指摘をどう直すかを Claude に相談するための文面をコピーします")
            .accessibilityLabel("改善プロンプトをコピー")
        }
    }

    private func copyPrompt() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(AdvicePrompt.text(for: advice, source: source), forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) { didCopy = true }
        // 押したことが分かれば十分なので、少し置いて自分で元に戻す。
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.15)) { didCopy = false }
        }
    }
}
