import SwiftUI
import Charts

/// コスト閲覧専用のポップオーバー。
/// 情報の優先度: 1) 今日いくら使ったか（ヒーロー） 2) 上限への近さ（予算・クォータ、
/// 設定時のみ） 3) 傾向と内訳（グラフ・モデル別・高額セッション）。
struct PopoverView: View {
    @ObservedObject var store: UsageStore
    var onOpenSettings: () -> Void = {}
    var onOpenAbout: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    budgetSection
                    if let report = store.report {
                        chartSection(report)
                        statsRow(report)
                        modelBreakdown(report)
                        topSessionsSection(report)
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
        }
    }

    // MARK: - 1. 今日のコスト（ヒーロー）

    private var heroSection: some View {
        let t = store.today
        return VStack(alignment: .leading, spacing: 2) {
            Text("今日")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.money(store.todayCost))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("\(t.prompts) プロンプト · \(t.sessions) セッション")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 2. 上限への近さ（設定している人にだけ見える）

    /// 予算の消費状況（今日・月）。上限を設定していなければ現れない。
    @ViewBuilder
    private var budgetSection: some View {
        let settings = AppSettings.shared
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
                Spacer()
                Picker("", selection: reportDaysSelection) {
                    Text("今日").tag(1)
                    Text("7日").tag(7)
                    Text("30日").tag(30)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 150)
                .labelsHidden()
            }
            Chart(report.dailySorted, id: \.date) { day in
                BarMark(
                    x: .value("Date", shortDate(day.date)),
                    y: .value("USD", day.cost)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues(report)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("$\(Int(v))")
                        }
                    }
                }
            }
            .frame(height: 110)
            // 期間切り替え中は古いグラフを薄くしてスピナーを重ね、再解析中であることを示す。
            .opacity(store.isReportLoading ? 0.3 : 1)
            .overlay {
                if store.isReportLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: store.isReportLoading)
        }
    }

    /// 期間合計と診断値。ヒーローと違い控えめな副次統計として1行に並べる。
    private func statsRow(_ report: RetokReport) -> some View {
        HStack(spacing: 0) {
            StatItem(label: "期間合計", value: Self.money(report.totals.cost))
            StatItem(label: "キャッシュヒット",
                     value: String(format: "%.0f%%", report.cacheHitRate * 100))
            StatItem(label: "プロンプト単価",
                     value: report.totals.prompts > 0
                        ? Self.money(report.totals.cost / Double(report.totals.prompts)) : "–")
        }
    }

    @ViewBuilder
    private func modelBreakdown(_ report: RetokReport) -> some View {
        let models = report.modelsSorted
        if !models.isEmpty {
            let maxCost = models.first?.usage.cost ?? 1
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("モデル別")
                ForEach(models, id: \.model) { entry in
                    HStack(spacing: 8) {
                        Text(shortModel(entry.model))
                            .font(.caption)
                            .lineLimit(1)
                            .frame(width: 100, alignment: .leading)
                        MeterBar(fraction: entry.usage.cost / maxCost, color: .secondary.opacity(0.45))
                        Text(Self.money(entry.usage.cost))
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

/// 予算 1 本ぶんの行（タイトル・消費/上限・メーター・警告ラベル）。今日と月で共用。
struct BudgetRow: View {
    let title: String
    let spend: Double
    let limit: Double
    let level: BudgetLevel
    let warnPercent: Int

    private var color: Color {
        switch level {
        case .over: return .red
        case .warning: return .orange
        case .ok: return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(PopoverView.money(spend)) / \(PopoverView.money(limit))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(level == .ok ? AnyShapeStyle(.secondary) : AnyShapeStyle(color))
            }
            MeterBar(fraction: spend / limit,
                     marker: Double(warnPercent) / 100,
                     color: color)
            if level == .over {
                Label("上限を超えています", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if level == .warning {
                Label("残り \(PopoverView.money(limit - spend))", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
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

/// 副次統計の 1 項目。数値は控えめに、色は使わない。
struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
