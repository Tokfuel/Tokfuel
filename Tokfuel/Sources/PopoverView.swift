import SwiftUI
import Charts

/// コスト閲覧専用のポップオーバー。
/// 情報の優先度: 1) 今日いくら使ったか（ヒーロー） 2) 上限への近さ（予算・クォータ、
/// 設定時のみ） 3) 傾向と内訳（グラフ・モデル別・高額セッション）。
struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var settings: AppSettings
    // ScreenshotRenderer がフッターのアップデートボタンをプレビューできるよう、フィクスチャの
    // UpdateChecker を差し込めるようにしてある（既定は実物の .shared）。
    @ObservedObject private var updater: UpdateChecker
    var onOpenSettings: () -> Void = {}
    var onOpenAbout: () -> Void = {}

    init(
        store: UsageStore,
        settings: AppSettings = .shared,
        updater: UpdateChecker = .shared,
        onOpenSettings: @escaping () -> Void = {},
        onOpenAbout: @escaping () -> Void = {}
    ) {
        self.store = store
        self.settings = settings
        self.updater = updater
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    budgetSection
                    if let report = store.report {
                        chartSection(report)
                        modelBreakdown(report)
                        if settings.costSourceMode.includesClaude {
                            topSessionsSection(report)
                            adviceSection(report)
                        }
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
        }
    }

    // MARK: - 1. 今日のコスト（ヒーロー）

    /// ヒーローは常に合計 1 つ。予算ゲージの分母（合算）と主役の数字を一致させ、
    /// 「今日使いすぎているか」に一目で答える（TF #53）。
    private var heroSection: some View {
        let mode = settings.costSourceMode
        return VStack(alignment: .leading, spacing: 2) {
            Text("今日")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.money(store.todayCost))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            // 並べて表示はヒーローを分割せず、内訳キャプション 1 行が担う。二次ソースは
            // driver ごとの実名で出し、0 円のソースは載せない（"その他" のような曖昧な
            // まとめラベルにしない）。
            if mode == .sideBySide {
                Text(Self.sideBySideCaption(claudeCost: store.claudeTodayCost,
                                            driverBreakdown: store.driverBreakdown))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if mode == .cursorOnly {
                Text("Cursor（推定）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 並べて表示のヒーロー内訳キャプション。driver ごとの実名で並べ、0 円のソースは省く
    /// （"その他" のような曖昧なまとめラベルにしない）。
    static func sideBySideCaption(claudeCost: Double,
                                  driverBreakdown: [(name: String, cost: Double)]) -> String {
        var parts = ["\(UsageStore.claudeSourceLabel) \(money(claudeCost))"]
        parts += driverBreakdown.filter { $0.cost > 0 }.map { "\($0.name) \(money($0.cost))" }
        return parts.joined(separator: " · ")
    }

    // MARK: - 2. 上限への近さ（設定している人にだけ見える）

    /// 予算の消費状況（今日・月）。上限を設定していなければ現れない。
    /// 並べて表示でもゲージの分母は合算（設定した上限との近さを見るため）。
    @ViewBuilder
    private var budgetSection: some View {
        if settings.dailyBudgetLimit > 0 {
            BudgetRow(title: "予算 (今日)", spend: store.todayCost, limit: settings.dailyBudgetLimit,
                      level: store.dailyBudgetLevel ?? .ok,
                      warnPercent: settings.budgetWarnPercent)
        }
        if settings.budgetLimit > 0 {
            BudgetRow(title: "予算 (\(settings.budgetPeriod == .calendarMonth ? "今月" : "30日"))",
                      spend: store.budgetSpend, limit: settings.budgetLimit,
                      level: store.budgetLevel ?? .ok,
                      warnPercent: settings.budgetWarnPercent)
        }
    }

    // MARK: - 3. 傾向と内訳

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
                Picker("", selection: reportDaysSelection) {
                    Text("7日").tag(7)
                    Text("30日").tag(30)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 100)
                .labelsHidden()
            }
            Group {
                switch store.costChartStyle {
                case .daily: dailyChart(report)
                case .cumulative: cumulativeChart(report)
                }
            }
            // 軸は両形式で共通: X はラベルのみ（縦グリッドとティックは引かない）、
            // Y は水平線 2〜3 本 — 色と線は情報を持つときだけ使う（TF #53）。
            .chartXAxis {
                AxisMarks(values: xAxisValues(report)) { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("$\(Int(v))")
                        }
                    }
                }
            }
            .frame(height: 110)
            // 再解析中も前回の絵を隠さない。右下の小さなインジケーターだけで進行を示す
            // （stale-while-revalidate — TF #53）。
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

    /// 日別の積み上げバー。塗りはフラット単色（TF #53）。
    private func dailyChart(_ report: RetokReport) -> some View {
        Chart(store.chartRows(for: report), id: \.id) { row in
            BarMark(
                x: .value("Date", shortDate(row.date)),
                y: .value("USD", row.cost)
            )
            .foregroundStyle(by: .value("Source", row.source))
            .cornerRadius(2)
        }
        .chartForegroundStyleScale([
            UsageStore.claudeSourceLabel: Color.accentColor,
            "Cursor": Color.secondary,
            "Codex": Color.purple
        ])
        .chartLegend(
            settings.costSourceMode.includesClaude
                && settings.costSourceMode.includesCursor
                && !store.driverDaily.isEmpty ? .visible : .hidden)
    }

    /// 期間の累積折れ線（合計 1 本）。予算窓と表示窓が一致するとき（store が判定する）だけ、
    /// 上限の参照線を破線で添える — ずれた期間に線を引くと嘘になる（TF #53）。
    private func cumulativeChart(_ report: RetokReport) -> some View {
        let points = UsageStore.cumulativeRows(
            from: store.chartRows(for: report),
            over: UsageStore.windowDates(days: report.periodDays))
        return Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", shortDate(point.date)),
                    y: .value("USD", point.total)
                )
            }
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            if case let .referenceLine(limit) = store.cumulativeBudgetAnnotation {
                RuleMark(y: .value("USD", limit))
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

    /// チャート直下の副次統計 1 行。期間合計と（Claude を含むときだけ）プロンプト単価、
    /// 累積ビューでは暦月予算の着地予測を添える。かつての 3 列 stats 行の置き換えで、
    /// キャッシュヒット率は出さない（ユーザーが操作できない診断値。異常時は節約のヒントが伝える）。
    private func chartCaption(_ report: RetokReport) -> some View {
        var parts = ["合計 \(Self.money(store.periodTotalCost(for: report)))"]
        if settings.costSourceMode.includesClaude, report.totals.prompts > 0 {
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
        if !report.topSessions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("高コストのセッション")
                ForEach(report.topSessions.prefix(3)) { session in
                    HStack(spacing: 8) {
                        Text(session.project)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(Self.money(session.cost))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func adviceSection(_ report: RetokReport) -> some View {
        if !report.advice.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("節約のヒント")
                ForEach(report.advice) { advice in
                    AdviceRow(advice: advice)
                }
            }
        }
    }

    // MARK: - 状態表示

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

    // MARK: - フッター（操作はここに集約）

    private var footerBar: some View {
        HStack {
            if let date = store.lastUpdated {
                Text("更新 \(date, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            #if DEBUG
            // どちらの構成を入れたかを、ホバーせずひと目で分かるようにする。
            // リリースビルドにはコンパイルされない。
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// アップデートがあるときだけ「⋯」の左に出す常設ボタン（TF #29）。縦のスペースを
    /// 取らない控えめな訴求にする。右クリックでその版を次回起動まで抑制する（「後で」相当）。
    /// 進行中はスピナーに、失敗時は警告アイコン（ホバーで理由）に、その場差し替え不可の
    /// 実行形態ではラベルをリリースページ導線に、それぞれ差し替わる。
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
                    .foregroundStyle(.orange)
                    .help(message + skipHint)
                case .idle:
                    Button(updater.installsInPlace ? "アップデート" : "リリースページを開く") {
                        updater.installOffered()
                    }
                    .foregroundStyle(Color.accentColor)
                    .help("v\(update.version) が利用可能です" + skipHint)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
            .contextMenu {
                Button("このバージョンをスキップ") { updater.skipOffered() }
            }
            .padding(.trailing, 4)
        }
    }

    // MARK: - 部品・ユーティリティ

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

    /// 期間ピッカー用バインディング。設定変更など画面外からの書き換えを
    /// period_change として誤記録しないよう、ピッカー操作のときだけ記録する。
    private var reportDaysSelection: Binding<Int> {
        Binding(get: { store.reportDays },
                set: { days in
                    store.reportDays = days
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost", "days": "\(days)"])
                })
    }

    /// チャート形式トグル用バインディング。期間ピッカーと同じ理由で操作時だけ記録する。
    private var chartStyleSelection: Binding<CostChartStyle> {
        Binding(get: { store.costChartStyle },
                set: { style in
                    store.costChartStyle = style
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost-style", "style": style.rawValue])
                })
    }

    /// X 軸に出す日付ラベル。10 日を超える期間では週の初めの日だけに間引く
    /// （30 日表示で全日付が潰れて読めなくなるのを防ぐ）。
    private func xAxisValues(_ report: RetokReport) -> [String] {
        let days = report.dailySorted
        guard days.count > 10 else { return days.map { shortDate($0.date) } }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        return days.filter { day in
            guard let date = f.date(from: day.date) else { return false }
            return cal.component(.weekday, from: date) == cal.firstWeekday
        }.map { shortDate($0.date) }
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        return parts.count == 3 ? "\(parts[1])/\(parts[2])" : date
    }

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20251001", with: "")
    }

    // 表示通貨（USD / JPY）を反映するフォーマッタ。actor 隔離なしで呼べる。
    nonisolated static func money(_ value: Double) -> String {
        Money.format(value)
    }
}

/// 予算 1 本ぶんの行（タイトル・右肩の状態テキスト・メーター）。今日と月で共用。
struct BudgetRow: View {
    let title: String
    let spend: Double
    let limit: Double
    let level: BudgetLevel
    let warnPercent: Int

    /// 色は状態を示すときだけ付ける: 平常はニュートラル、警告でオレンジ、超過で赤。
    /// 平常までアクセント色で塗ると、警告のオレンジと見分けがつかない（TF #53）。
    private var color: Color {
        switch level {
        case .over: return .red
        case .warning: return .orange
        case .ok: return .secondary.opacity(0.45)
        }
    }

    var body: some View {
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

    /// 右肩の 1 行。平常は消費/上限、警告は残額、超過は超過額（アイコンは超過のみ）。
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

/// 細い水平メーター。予算・モデル別で共用する。marker を渡すと目盛り線を引く。
struct MeterBar: View {
    let fraction: Double
    var marker: Double? = nil
    var color: Color = .accentColor

    var body: some View {
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

/// retok の推奨事項 1 件。タップで詳細を開閉する。
struct AdviceRow: View {
    let advice: RetokReport.Advice
    @State private var isExpanded = false

    private var color: Color {
        switch advice.severity {
        case "high": return .red
        case "medium", "warn": return .orange
        default: return .secondary.opacity(0.8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: advice.severity == "high"
                      ? "exclamationmark.triangle.fill" : "lightbulb")
                    .font(.caption)
                    .foregroundStyle(color)
                Text(advice.title)
                    .font(.caption)
                    .lineLimit(isExpanded ? nil : 1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            if isExpanded {
                Text(advice.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        }
    }
}
