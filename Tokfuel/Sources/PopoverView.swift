import SwiftUI
import Charts

struct PopoverView: View {
    enum Tab: String, CaseIterable {
        case cost = "Cost"
        case tools = "Tools"
        case skills = "Skills"
    }

    @ObservedObject var store: UsageStore
    var onOpenSettings: () -> Void = {}
    @State private var selectedGenre: String?
    @State private var trendDays: Int = 7
    @State private var unusedOnly: Bool = true
    @State private var tab: Tab = .cost

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .cost:
                        costSection
                    case .tools:
                        todaySection
                        summaryCards
                        dailySection
                        topToolsSection
                        genreSection
                        repoSection
                    case .skills:
                        skillInventorySection
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 560)
        // 初期表示のタブも数えるため、切り替えだけでなく表示時にも記録する。
        .onAppear {
            UsageEventLog.shared.log(.tabOpen, meta: ["tab": tab.rawValue.lowercased()])
        }
        .onChange(of: tab) { _, newTab in
            UsageEventLog.shared.log(.tabOpen, meta: ["tab": newTab.rawValue.lowercased()])
        }
        .onChange(of: trendDays) { _, days in
            UsageEventLog.shared.log(.periodChange, meta: ["picker": "trend", "days": "\(days)"])
        }
    }

    /// Cost タブの期間ピッカー用バインディング。設定変更など画面外からの書き換えを
    /// period_change として誤記録しないよう、ピッカー操作のときだけ記録する。
    private var reportDaysSelection: Binding<Int> {
        Binding(get: { store.reportDays },
                set: { days in
                    store.reportDays = days
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost", "days": "\(days)"])
                })
    }

    // MARK: - Cost タブ（retok レポート）

    @ViewBuilder
    private var costSection: some View {
        if let error = store.retokError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if let report = store.report {
            costOverview(report)
            budgetSection
            dailyCostChart(report)
            modelBreakdown(report)
            adviceSection(report)
            topSessionsSection(report)
            retokCredit
        } else if store.retokError == nil {
            HStack {
                Spacer()
                ProgressView("解析中…")
                    .controlSize(.small)
                Spacer()
            }
            .padding(.vertical, 40)
        }
    }

    private func costOverview(_ report: RetokReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cost (\(report.periodDays)d / \(report.filesScanned) files)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: reportDaysSelection) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            HStack(spacing: 8) {
                CostCard(label: "Today",
                         value: store.todayCost.map { Self.money($0) } ?? "–",
                         color: .blue)
                CostCard(label: "Total", value: Self.money(report.totals.cost), color: .indigo)
                CostCard(label: "Cache hit",
                         value: String(format: "%.1f%%", report.cacheHitRate * 100),
                         color: report.cacheHitRate > 0.8 ? .green : .orange)
                CostCard(label: "$/prompt",
                         value: report.totals.prompts > 0
                            ? Self.money(report.totals.cost / Double(report.totals.prompts)) : "–",
                         color: .purple)
            }
        }
    }

    private func dailyCostChart(_ report: RetokReport) -> some View {
        let days = report.dailySorted
        return VStack(alignment: .leading, spacing: 8) {
            Text("Daily cost")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart(days, id: \.date) { day in
                BarMark(
                    x: .value("Date", shortDate(day.date)),
                    y: .value("USD", day.cost)
                )
                .foregroundStyle(.blue.gradient)
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
            .frame(height: 120)
        }
    }

    private func modelBreakdown(_ report: RetokReport) -> some View {
        let models = report.modelsSorted
        let maxCost = models.first?.usage.cost ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            Text("By model")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(models, id: \.model) { entry in
                HStack(spacing: 6) {
                    Text(shortModel(entry.model))
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(.indigo.opacity(0.25))
                            .frame(width: max(4, geo.size.width * entry.usage.cost / maxCost))
                    }
                    .frame(height: 10)
                    Text(Self.money(entry.usage.cost))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.indigo)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func adviceSection(_ report: RetokReport) -> some View {
        if !report.advice.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommendations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(report.advice) { advice in
                    AdviceRow(advice: advice)
                }
            }
        }
    }

    @ViewBuilder
    private func topSessionsSection(_ report: RetokReport) -> some View {
        if !report.topSessions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Top sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(report.topSessions.prefix(5)) { session in
                    HStack(spacing: 6) {
                        Text(session.project)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text("\(session.maxContext / 1000)k ctx")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(Self.money(session.cost))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.blue)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    /// 予算の消費状況バー。設定した上限に対する現在の消費額と割合を示す。
    @ViewBuilder
    private var budgetSection: some View {
        let settings = AppSettings.shared
        if settings.budgetLimit > 0, let spend = store.budgetSpend {
            let limit = settings.budgetLimit
            let ratio = min(spend / limit, 1.0)
            let level = store.budgetLevel ?? .ok
            let color: Color = level == .over ? .red : (level == .warning ? .orange : .green)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Budget (\(settings.budgetPeriod == .calendarMonth ? "今月" : "過去30日"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Self.money(spend)) / \(Self.money(limit))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                    Text("\(Int(spend / limit * 100))%")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(color.gradient)
                            .frame(width: max(6, geo.size.width * ratio))
                        // 警告しきい値の目盛り
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 1.5)
                            .offset(x: geo.size.width * Double(settings.budgetWarnPercent) / 100)
                    }
                }
                .frame(height: 10)
                if level == .over {
                    Label("上限を超えています", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if level == .warning {
                    Label("上限に近づいています（残り \(Self.money(limit - spend))）",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// retok（© Daiki Matsudate, MIT License）への帰属表示。
    private var retokCredit: some View {
        HStack(spacing: 4) {
            Text("Powered by")
                .foregroundStyle(.tertiary)
            Link("retok", destination: URL(string: "https://github.com/d-date/retok")!)
            Text("© Daiki Matsudate (MIT)")
                .foregroundStyle(.tertiary)
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        return parts.count == 3 ? "\(parts[1])/\(parts[2])" : date
    }

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20251001", with: "")
    }

    static func money(_ value: Double) -> String {
        value >= 100 ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
    }

    /// Overview と Skills（未使用 Skill の洗い出し）を切り替えるタブ。
    private var tabBar: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { t in
                if t == .skills, store.skillInventory.contains(where: \.isUnused) {
                    Text("\(t.rawValue) (\(store.skillInventory.filter(\.isUnused).count))").tag(t)
                } else {
                    Text(t.rawValue).tag(t)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// P1: 今日の使用量と前日比。開いた瞬間に「今日どれだけ使ったか」が分かる。
    private var todaySection: some View {
        let t = store.today
        let y = store.yesterday
        return VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TodayCard(label: "Prompts", value: t.prompts,
                          previous: y?.prompts, color: .blue)
                TodayCard(label: "Tools", value: t.totalTools,
                          previous: y?.totalTools, color: .indigo)
                TodayCard(label: "+Lines", value: t.editsAdded,
                          previous: y?.editsAdded, color: .green)
            }
        }
    }

    /// P3: 全リポジトリ横断で「よく使う Skill / MCP」TOP5。使い方の偏りを把握する。
    private var topToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most used")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.topSkills.isEmpty && store.topMCP.isEmpty {
                Text("まだデータがありません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                if !store.topSkills.isEmpty {
                    RankingList(title: "Skills", color: .purple,
                                items: Array(store.topSkills.prefix(5)))
                }
                if !store.topMCP.isEmpty {
                    RankingList(title: "MCP", color: .green,
                                items: Array(store.topMCP.prefix(5)))
                }
            }
        }
    }

    /// 不要 Skill の洗い出し。Global / Plugin / Project別のスコープごとにまとめ、
    /// 各グループ内は使用数の少ない順。0 回（削除候補）を目立たせる。
    private var skillInventorySection: some View {
        let groups = store.skillGroups(unusedOnly: unusedOnly)
        let unusedCount = store.skillInventory.filter(\.isUnused).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skill inventory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if unusedCount > 0 {
                    Text("\(unusedCount) unused")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.red.opacity(0.12), in: Capsule())
                }
                Spacer()
                Toggle("未使用のみ", isOn: $unusedOnly)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.caption2)
            }

            if groups.isEmpty {
                Text(unusedOnly ? "未使用の Skill はありません 🎉" : "Skill が見つかりません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                Label("行をクリックすると Finder で該当フォルダを開きます", systemImage: "hand.tap")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                ForEach(groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(group.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text("\(group.items.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(group.items) { item in
                            SkillInventoryRow(item: item)
                        }
                    }
                }
            }
        }
    }

    /// 直近 N 日分の、日ごとのツール内訳（Skills / MCP / Agents）積み上げ棒グラフ。
    private var dailySection: some View {
        let recent = store.recentDaily(trendDays)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily activity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $trendDays) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            if recent.isEmpty {
                Text("まだデータがありません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                Chart {
                    ForEach(recent) { day in
                        ForEach(day.breakdown, id: \.kind) { slice in
                            BarMark(
                                x: .value("Date", day.shortDate),
                                y: .value("Calls", slice.count)
                            )
                            .foregroundStyle(by: .value("Kind", slice.kind))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Skills": Color.purple,
                    "MCP": Color.green,
                    "Agents": Color.orange
                ])
                .chartLegend(position: .bottom, spacing: 4)
                .frame(height: 140)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(.secondary)
            Text("Claude Code Usage")
                .font(.headline)
            Spacer()
            if let date = store.lastUpdated {
                Text(date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("再読み込み")

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("設定")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("終了")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summaryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            MetricCard(label: "Skills", value: store.totalSkills, color: .purple)
            MetricCard(label: "MCP", value: store.totalMCP, color: .green)
            MetricCard(label: "Agents", value: store.totalSubagents, color: .orange)
            MetricCard(label: "Prompts", value: store.totalPrompts, color: .blue)
        }
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By genre")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(store.genres) { genre in
                GenreRow(genre: genre, isSelected: selectedGenre == genre.genre)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedGenre = selectedGenre == genre.genre ? nil : genre.genre
                        }
                    }
            }
        }
    }

    private var filteredRepos: [RepoUsage] {
        // ツール呼び出しが 0 件のリポジトリは表示しない。
        let nonEmpty = store.repos.filter { $0.totalToolCalls > 0 }
        if let g = selectedGenre {
            return nonEmpty.filter { $0.genre == g }
        }
        return nonEmpty
    }

    private var repoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedGenre.map { "Repos (\($0))" } ?? "All repos")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(filteredRepos) { repo in
                RepoRow(repo: repo)
            }
        }
    }
}

/// コスト系の値（文字列フォーマット済み）を表示するカード。
struct CostCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// retok の推奨事項 1 件。severity に応じて色分けし、タップで詳細を開閉する。
struct AdviceRow: View {
    let advice: RetokReport.Advice
    @State private var isExpanded = false

    private var color: Color {
        switch advice.severity {
        case "high": return .red
        case "medium", "warn": return .orange
        default: return .blue
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
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(isExpanded ? nil : 1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            if isExpanded {
                Text(advice.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        }
    }
}

/// 今日の値と前日比を表示するカード。前日比は色付き矢印で直感的に示す。
struct TodayCard: View {
    let label: String
    let value: Int
    let previous: Int?
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            deltaView
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var deltaView: some View {
        if let prev = previous, prev > 0 {
            let diff = value - prev
            let pct = Int((Double(diff) / Double(prev) * 100).rounded())
            HStack(spacing: 2) {
                Image(systemName: diff > 0 ? "arrow.up" : (diff < 0 ? "arrow.down" : "minus"))
                    .font(.system(size: 8, weight: .bold))
                Text("\(abs(pct))%")
                    .font(.system(size: 10, design: .rounded))
            }
            .foregroundStyle(diff > 0 ? .green : (diff < 0 ? .red : .secondary))
        } else {
            Text("前日比 –")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Skill 棚卸しの 1 行。未使用は赤、使用済みは回数を表示。個人/プラグインをバッジで区別。
/// Skill 棚卸しの 1 行。クリックで Skill の実体フォルダを Finder に表示する
/// （削除はせず、ユーザー自身が中身を確認して判断できるようにする）。
struct SkillInventoryRow: View {
    let item: SkillInventoryItem
    @State private var isHovering = false

    var body: some View {
        Button(action: revealInFinder) {
            HStack(spacing: 8) {
                Circle()
                    .fill(item.isUnused ? Color.red : Color.green)
                    .frame(width: 7, height: 7)

                Text(item.name)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(item.isUnused ? .primary : .secondary)

                Spacer()

                Text(item.isUnused ? "未使用" : "\(item.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.isUnused ? .red : .secondary)

                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(isHovering ? .primary : .tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Finder で開く: \(item.url.path)")
    }

    private var background: AnyShapeStyle {
        if isHovering { return AnyShapeStyle(.blue.opacity(0.12)) }
        return item.isUnused ? AnyShapeStyle(.red.opacity(0.06))
                             : AnyShapeStyle(.quaternary.opacity(0.5))
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}

/// よく使うツールの横棒ランキング。最大値を基準に相対バーで偏りを可視化する。
struct RankingList: View {
    let title: String
    let color: Color
    let items: [(name: String, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            let maxCount = items.map(\.count).max() ?? 1
            ForEach(items, id: \.name) { item in
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .frame(width: 150, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(color.opacity(0.25))
                            .frame(width: max(4, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)))
                    }
                    .frame(height: 10)
                    Text("\(item.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(color)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}

struct MetricCard: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(formatNumber(value))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

struct GenreRow: View {
    let genre: GenreSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: genreIcon)
                .frame(width: 16)
                .foregroundStyle(genreColor)
            Text(genre.genre)
                .font(.callout)
                .fontWeight(.medium)
            Spacer()
            HStack(spacing: 12) {
                StatPill(icon: "wand.and.stars", value: genre.skills, color: .purple)
                StatPill(icon: "link", value: genre.mcp, color: .green)
                StatPill(icon: "text.bubble", value: genre.prompts, color: .blue)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isSelected ? 90 : 0))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? AnyShapeStyle(genreColor.opacity(0.08)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
    }

    private var genreIcon: String {
        switch genre.genre {
        case "work": return "building.2"
        case "personal": return "person"
        case "side-project": return "hammer"
        default: return "folder"
        }
    }

    private var genreColor: Color {
        switch genre.genre {
        case "work": return .blue
        case "personal": return .purple
        case "side-project": return .orange
        default: return .gray
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(value)")
                .font(.system(size: 11, design: .rounded))
        }
        .foregroundStyle(color)
    }
}

struct RepoRow: View {
    let repo: RepoUsage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(repo.repo)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Text("\(repo.totalToolCalls)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        MiniStat(label: "Skills", value: repo.skillCalls, color: .purple)
                        MiniStat(label: "MCP", value: repo.mcpCalls, color: .green)
                        MiniStat(label: "Agents", value: repo.subagentCalls, color: .orange)
                        MiniStat(label: "Prompts", value: repo.promptCount, color: .blue)
                    }

                    if !repo.topSkills.isEmpty {
                        Text("Top skills")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        FlowLayout(spacing: 4) {
                            ForEach(repo.topSkills.prefix(5), id: \.name) { skill in
                                Text("\(skill.name) (\(skill.count))")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.purple.opacity(0.1), in: Capsule())
                            }
                        }
                    }

                    if !repo.topMCP.isEmpty {
                        Text("Top MCP")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        FlowLayout(spacing: 4) {
                            ForEach(repo.topMCP.prefix(5), id: \.name) { tool in
                                Text("\(tool.name) (\(tool.count))")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .padding(.leading, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
    }
}

struct MiniStat: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
