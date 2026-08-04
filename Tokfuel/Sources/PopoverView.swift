import AppKit
import SwiftUI
import Charts

/// コスト閲覧専用のポップオーバー。
/// 情報の優先度: 1) 今日いくら使ったか（ヒーロー） 2) 上限への近さ（予算・クォータ、
/// 設定時のみ） 3) 傾向と内訳（グラフ・モデル別・高額セッション）。
struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var settings: AppSettings
    // private ではない — ScreenshotRenderer がフッターのアップデートボタンをプレビュー
    // させるために、フィクスチャの UpdateChecker を渡せるようにする（既定は実物の .shared）。
    @ObservedObject var updater: UpdateChecker
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
                        // セッションは二次ソースも出せるのでソースモードの外に置く。
                        topSessionsSection(report)
                        // ヒントは Claude だけの話ではない（Cursor 由来も並ぶ）ので、
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
            // サインインしに行ったあとの初回だけ、10 分の定期更新を待たずに拾い直す。
            if store.awaitingSignInRecheck {
                store.awaitingSignInRecheck = false
                store.reloadReport()
            }
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
            // 取れなかったぶんだけで作った 0 円は誤情報なので、金額ではなく「—」を出す
            // （Cursor のみのモードで Cursor が劣化したときに起きる）。
            Text(store.todayCostUnavailable ? "—" : Self.money(store.todayCost))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            // 並べて表示はヒーローを分割せず、内訳キャプション 1 行が担う。二次ソースは
            // driver ごとの実名で出し、0 円のソースは載せない（"その他" のような曖昧な
            // まとめラベルにしない）。
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
            unpricedNotices
            unbilledNotices
        }
    }

    /// 金額を出せなかった使用の注意書き（#91）。劣化警告と同じ強さで出す——どちらも
    /// 「表示中の金額が実態より小さい」ことを伝える行なので、色を分ける理由が無い。
    @ViewBuilder
    private var unpricedNotices: some View {
        ForEach(store.unpricedSourceNotices) { notice in
            Label("\(notice.name): \(notice.message)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Self.warningTint)
                .padding(.top, 6)
        }
    }

    /// プラン枠内・無課金で $0 になっている使用の注意書き（#100）。金額そのものは正しいので
    /// 警告色にはせず、$0 を「今日は使っていない」と読ませないための補足に留める。
    @ViewBuilder
    private var unbilledNotices: some View {
        ForEach(store.unbilledSourceNotices) { notice in
            Label("\(notice.name): \(notice.message)", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
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
                    // 手順は注意書きの 1 行が担う。ボタンは実際にできること（前面に出す）を
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
    /// そのままライト側ではコントラスト不足になるため（ライトでは暗い側へ寄せる）。
    static let warningTint = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.00, green: 0.30, blue: 0.24, alpha: 1)
            : NSColor(srgbRed: 0.82, green: 0.10, blue: 0.06, alpha: 1)
    })

    /// 指定アプリを前面に出す。見つからなければ何もしない（アンインストール直後など）。
    /// サインインの完了は監視しない——10 分ごとの定期更新か、次にポップオーバーを開いた
    /// ときの再取得が新しいトークンを拾う。
    static func activateApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// 並べて表示のヒーロー内訳キャプション。driver ごとの実名で並べ、0 円のソースは省く
    /// （"その他" のような曖昧なまとめラベルにしない）。
    /// 取得できなかったソースは 0 円として並べず「—」にする——0 円と「不明」は別の情報。
    static func sideBySideCaption(claudeCost: Double,
                                  driverBreakdown: [(name: String, cost: Double)],
                                  unknownSources: [String] = []) -> String {
        var parts = ["\(UsageStore.claudeSourceLabel) \(money(claudeCost))"]
        parts += driverBreakdown.filter { $0.cost > 0 }.map { "\($0.name) \(money($0.cost))" }
        parts += unknownSources.map { "\($0) —" }
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
            // 軸は両形式で共通: X はラベルのみ（縦グリッドとティックは引かない）、
            // Y は水平線 2〜3 本 — 色と線は情報を持つときだけ使う（TF #53）。
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
        let rows = store.chartRows(for: report)
        // 凡例は系列が 2 つ以上あるときだけ意味を持つ（単独ソースでは 1 色しか出ない）。
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

    /// チャート系列用。内部 USD を表示通貨建てに直す（軸のきれいな目盛りのため）。
    private func chartAmount(_ usd: Double) -> Double {
        Money.displayAmount(
            forUSD: usd,
            currency: settings.displayCurrency,
            rate: Money.currentRate())
    }

    /// チャート直下の副次統計 1 行。期間合計と（Claude を含むときだけ）プロンプト単価、
    /// 累積ビューでは暦月予算の着地予測を添える。かつての 3 列 stats 行の置き換えで、
    /// キャッシュヒット率は出さない（ユーザーが操作できない診断値。異常時は節約のヒントが伝える）。
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

    /// 高コストの会話。Claude（retok のセッション）と二次ソース（Cursor の会話）を
    /// コスト降順で 1 本のリストにする。どちらの会話かが分かるようソース名を添え、
    /// ローカル DB から起こした二次ソースには「推定」まで添える（合計とは別物）。
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

    /// retok（Claude）由来と Cursor 由来を 1 つのリストで出す。合成・並び順・ソースごとの
    /// 抑止はすべて store が決める（ここは並べるだけ）。
    @ViewBuilder
    private func adviceSection(_ report: RetokReport) -> some View {
        let items = store.adviceItems(for: report)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("節約のヒント")
                ForEach(items) { item in
                    AdviceRow(advice: item.advice, source: item.source)
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
            // アクセントのオレンジは「注意して見るもの」（予算の警告・アップデート）に
            // 取っておく。常設の操作口は左隣の更新時刻と同じ灰色に揃える。
            // borderlessButton のラベルはティントで塗られるので、
            // ラベル側の foregroundStyle ではなくここで色を指定する。
            .tint(Color(nsColor: .tertiaryLabelColor))
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
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .help(message + skipHint)
                case .idle:
                    // フッターの DEBUG バッジと同じカプセル型のレシピ（塗り + 白文字）で、
                    // 他の要素より一段目立たせる。
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
    private var reportPeriodSelection: Binding<ReportPeriod> {
        Binding(get: { store.reportPeriod },
                set: { period in
                    store.reportPeriod = period
                    UsageEventLog.shared.log(.periodChange,
                                             meta: ["picker": "cost", "period": period.rawValue])
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

    /// X 軸に出すカテゴリ値（`shortDate` と同じ MM/DD）。チャートの X と一致させる。
    private func xAxisValues(_ report: RetokReport) -> [String] {
        let dates: [String]
        switch store.costChartStyle {
        case .cumulative:
            // 累積は窓の全日がカテゴリになるので、ラベル候補も窓に合わせる。
            dates = UsageStore.windowDates(days: report.periodDays)
        case .daily:
            let fromRows = Array(Set(store.chartRows(for: report).map(\.date))).sorted()
            if fromRows.isEmpty {
                // chartRows が空でも、retok の余剰日を軸に載せない。
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

    /// 期間に応じて X 軸ラベル用の MM/DD を間引く。今年は月初だけ（必要ならさらに間引く）。
    nonisolated static func xAxisShortDates(
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
            // 週ごとだと約 52 個になり潰れる。月初に落とす。多すぎるときだけ均等間引き。
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

    /// 軸に載せる文字列。今年は「M月」にして幅を抑える（カテゴリ値自体は MM/DD のまま）。
    nonisolated static func xAxisLabel(_ shortDate: String, period: ReportPeriod) -> String {
        guard period == .thisYear else { return shortDate }
        let parts = shortDate.split(separator: "/")
        guard let month = parts.first.flatMap({ Int($0) }) else { return shortDate }
        return "\(month)月"
    }

    /// 先頭と末尾を含むよう、最大 `maxCount` 個へ均等に間引く。
    nonisolated static func evenlySpaced(_ items: [String], maxCount: Int) -> [String] {
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

    nonisolated static func shortDate(_ date: String) -> String {
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

/// 節約のヒント 1 件。タップで詳細を開閉する。
/// 出どころ（Claude / Cursor）はバッジで示す — 同じリストに 2 系統が並ぶので、
/// どちらを見て言っているのかが分からないとヒントを判断に使えない。
struct AdviceRow: View {
    let advice: RetokReport.Advice
    let source: String
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
