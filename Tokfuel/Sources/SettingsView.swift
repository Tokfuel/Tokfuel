import SwiftUI
import AppKit

/// 設定ウィンドウ。よく触る「一般 / メニューバー / 予算」だけを見せ、
/// めったに変えない項目（レポート言語・スキャン場所・イベントログ）は「詳細」に畳む。
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    #if DEBUG
    @ObservedObject private var debug = DebugSettings.shared
    #endif
    /// メニューバー表示のライブプレビューに実データを出すためのストア。
    /// 集計が非同期に届いたらプレビューも追従させたいので監視する。
    @ObservedObject var store: UsageStore
    @State private var showsAdvanced = false
    #if DEBUG
    @State private var showsDebug = false
    #endif

    var body: some View {
        Form {
            Section("一般") {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("ログイン時に自動起動")
                }
                Picker("通貨", selection: $settings.displayCurrency) {
                    ForEach(DisplayCurrency.allCases) { Text($0 == .usd ? "$ ドル" : "¥ 円").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Section {
                Picker("見る指標", selection: $settings.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases) { Text($0.label).tag($0) }
                }

                // 表現はプレビュー付きのラジオで並べる。分母を持てない組み合わせは
                // 選べないようにして、選んだのに金額のままという食い違いを防ぐ。
                ForEach(representationRows) { representationRow($0) }

                if settings.menuBarRepresentation.drawsRing {
                    Picker("ゲージの形", selection: $settings.menuBarGaugeShape) {
                        ForEach(MenuBarGaugeShape.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                    // タンクはアイコン自身がゲージなので、併記の選択肢が意味を持たない。
                    if settings.menuBarGaugeShape.isSeparateFromIcon {
                        Toggle("アイコンも並べる", isOn: $settings.menuBarShowsIcon)
                    }
                }

                // 基準は、割合表現を選んでいなくても出す。選んだあとにしか出さないと、
                // 予算未設定のユーザーはパーセントとリングが永久にグレーのままになる
                // （選べない → 基準を変えられない → 選べない）。
                if settings.menuBarMetric.supportsRatio {
                    Picker("割合の基準", selection: $settings.menuBarPercentBasis) {
                        ForEach(MenuBarPercentBasis.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                    Text(settings.menuBarPercentBasis.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // ON のままだと上限を消したあとに解除できなくなるので、すでに ON なら出し続ける。
                if settings.budgetLimit > 0 || settings.dailyBudgetLimit > 0
                    || settings.menuBarShowsRemaining {
                    Toggle("予算までの残りを表示", isOn: $settings.menuBarShowsRemaining)
                }
            } header: {
                Text("メニューバー")
            } footer: {
                if let note = menuBarNote(for: store.menuBarInput()) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Text("月の上限 (\(unitSymbol))")
                    Spacer()
                    TextField("", value: budgetField(\.budgetLimit), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                if settings.budgetLimit > 0 {
                    Picker("集計期間", selection: $settings.budgetPeriod) {
                        ForEach(BudgetPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                }
                HStack {
                    Text("1日の上限 (\(unitSymbol))")
                    Spacer()
                    TextField("", value: budgetField(\.dailyBudgetLimit), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                if settings.budgetLimit > 0 || settings.dailyBudgetLimit > 0 {
                    Picker("警告しきい値", selection: $settings.budgetWarnPercent) {
                        Text("70%").tag(70)
                        Text("80%").tag(80)
                        Text("90%").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            } header: {
                Text("予算")
            } footer: {
                Text("しきい値でアイコンがオレンジになり通知、超過で赤になります。円は Frankfurter API のレート（1 日 1 回取得・レート以外は送信しません）で換算し、内部では USD で保存します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DisclosureGroup("詳細", isExpanded: $showsAdvanced) {
                    Picker("レポート言語", selection: $settings.language) {
                        ForEach(ReportLanguage.allCases) { Text($0.label).tag($0) }
                    }

                    PathRow(title: "Claude ディレクトリ",
                            note: "コスト集計元のトランスクリプト (projects) の読み取り元",
                            path: $settings.claudeDirectory,
                            defaultPath: AppSettings.defaultClaudeDirectory)

                    Toggle(isOn: $settings.eventLogEnabled) {
                        Text("利用イベントを記録")
                        Text("Tokfuel 自身の操作イベントだけを Mac 内に記録します（外部送信なし）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("ログを表示") {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [UsageEventLog.shared.revealDirectoryURL()])
                        }
                        .controlSize(.small)
                        Button("全イベントを削除", role: .destructive) {
                            UsageEventLog.shared.deleteAll()
                        }
                        .controlSize(.small)
                    }
                }
            }

            #if DEBUG
            // 開発者向け。リリースビルドにはコンパイルされない。「詳細」と同じく畳んでおく。
            Section {
                DisclosureGroup("デバッグ", isExpanded: $showsDebug) {
                    // 今日側と月側は別々の retok 実行なので、片方だけ欠けた状態も再現できる。
                    Toggle(isOn: $debug.simulatesMissingReport) {
                        Text("未取得を再現: 今日")
                        Text("今日のコストが 0 になり、推移・内訳は読み込み中表示に落ちます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle(isOn: $debug.simulatesMissingMonth) {
                        Text("未取得を再現: 今月")
                        Text("月の 32 日集計だけが未着。起動直後に数秒だけ通る状態です")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle(isOn: $debug.isActive) {
                        Text("金額を上書きする")
                        Text("上書き中は retok の実データを使いません。値は保存されず、再起動で元に戻ります")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if debug.isActive {
                        if !debug.simulatesMissingReport {
                            DebugAmountRow(title: "今日のコスト ($)",
                                           range: 0...50, value: $debug.todayCost)
                        }
                        if !debug.simulatesMissingMonth {
                            DebugAmountRow(title: "今月のコスト ($)",
                                           range: 0...500, value: $debug.monthCost)
                            DebugAmountRow(title: "日次平均 ($)",
                                           range: 0...50, value: $debug.averageCost)
                        }
                    }
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
    }

    /// 予算入力欄の単位。円を選んでいてもレート未取得なら USD 入力のまま。
    private var unitSymbol: String {
        settings.displayCurrency == .jpy
            && UserDefaults.standard.double(forKey: Money.rateKey) > 0 ? "¥" : "$"
    }

    /// 予算上限（内部保存は USD）を、選択中の通貨で入出力するバインディング。
    /// 円のときは取得済みレートで換算し、整数円に丸めて見せる。
    private func budgetField(_ keyPath: ReferenceWritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding(
            get: {
                let usd = settings[keyPath: keyPath]
                let rate = UserDefaults.standard.double(forKey: Money.rateKey)
                if settings.displayCurrency == .jpy, rate > 0 {
                    return (usd * rate).rounded()
                }
                return usd
            },
            set: { value in
                let rate = UserDefaults.standard.double(forKey: Money.rateKey)
                if settings.displayCurrency == .jpy, rate > 0 {
                    settings[keyPath: keyPath] = value / rate
                } else {
                    settings[keyPath: keyPath] = value
                }
            })
    }

    /// 表現 1 行ぶんの素材。
    private struct RepresentationRow: Identifiable {
        let option: MenuBarRepresentation
        let selectable: Bool
        let content: MenuBarContent
        var id: String { option.rawValue }
    }

    /// 全行ぶんをまとめて組む。入力（集計値と日付計算）はここで 1 度だけ作る
    /// ——行ごとに組み直すと、同じ計算を表現の数だけやり直すことになる。
    private var representationRows: [RepresentationRow] {
        let input = store.menuBarInput()
        return MenuBarRepresentation.allCases.map { option in
            var probe = input
            probe.representation = option
            return RepresentationRow(
                option: option,
                selectable: MenuBarReadout.isSelectable(
                    metric: settings.menuBarMetric, representation: option,
                    basis: settings.menuBarPercentBasis,
                    dailyLimit: settings.dailyBudgetLimit, monthlyLimit: settings.budgetLimit),
                content: MenuBarReadout.content(for: probe))
        }
    }

    /// 表現 1 つぶんの行（ラジオ + ラベル + 実データのプレビュー）。
    /// 選べない表現はプレビューを出さない（出すと選べるように見える）。
    private func representationRow(_ row: RepresentationRow) -> some View {
        let selected = settings.menuBarRepresentation == row.option
        return Button {
            // @Published は同値でも発火する。選択済みの行を押しただけで
            // 32 日集計（python3）が走らないよう、変化したときだけ書く。
            if settings.menuBarRepresentation != row.option {
                settings.menuBarRepresentation = row.option
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "inset.filled.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(row.option.label)
                Spacer()
                if row.selectable {
                    MenuBarPreviewChip(image: MenuBarImage.statusItem(for: row.content),
                                       text: row.content.title.isEmpty ? nil : row.content.title)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.selectable)
    }

    /// グレーアウトや金額へのフォールバックの理由。見た目だけでは伝わらないので添える。
    private func menuBarNote(for input: MenuBarInput) -> String? {
        switch MenuBarReadout.ratioUnavailability(
            metric: settings.menuBarMetric, basis: settings.menuBarPercentBasis,
            dailyLimit: settings.dailyBudgetLimit, monthlyLimit: settings.budgetLimit) {
        case .noRatio:
            return "プロンプト数には分母が無いため、パーセントとリングは選べません。"
        case .noLimit:
            return "予算上限を基準にするには、選んだ指標の上限を設定してください。"
                + "予算なしで割合を見たいときは基準を「過去 30 日の日次平均」にします。"
        case nil:
            // 選べてはいるが、まだ分母が無くて金額に落ちている状態を伝える。
            guard settings.menuBarRepresentation.needsBasis,
                  !MenuBarReadout.canRender(metric: settings.menuBarMetric,
                                            representation: settings.menuBarRepresentation,
                                            gauge: input.gauge) else { return nil }
            return "コストの記録がまだ足りないため、いまは金額で表示しています。"
        }
    }
}

#if DEBUG
/// デバッグ用の金額入力（スライダーで大まかに、数値欄で正確に）。
struct DebugAmountRow: View {
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                TextField("", value: $value, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 2)
    }
}
#endif

/// メニューバーの見た目を模したプレビューチップ（画像 + タイトル）。
/// 画像は本物のステータス項目と同じ組み立てを通すので、見た目が実物と乖離しない。
struct MenuBarPreviewChip: View {
    var image: NSImage?
    let text: String?

    var body: some View {
        HStack(spacing: 3) {
            if let image {
                Image(nsImage: image)
            }
            if let text {
                Text(text)
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// フォルダパス 1 件を表示し、Finder のパネルで選択・デフォルトに戻せる行。
struct PathRow: View {
    let title: String
    let note: String
    @Binding var path: String
    let defaultPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                if abbreviated(path) != abbreviated(defaultPath) {
                    Button("デフォルト") { path = defaultPath }
                        .controlSize(.small)
                }
                Button("変更…") { choose() }
                    .controlSize(.small)
            }
            Text(abbreviated(path))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func abbreviated(_ p: String) -> String {
        (p as NSString).abbreviatingWithTildeInPath
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
