import SwiftUI
import AppKit

/// 設定ウィンドウ。よく触る「一般 / メニューバー / 予算」だけを見せ、
/// めったに変えない項目（レポート言語・スキャン場所・イベントログ）は「詳細」に畳む。
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    /// メニューバー表示のプレビューに実データを出すためのストア（省略時はプレースホルダ表示）。
    var store: UsageStore?
    @State private var showsAdvanced = false

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

            Section("メニューバー") {
                ForEach(MenuBarDisplay.allCases) { option in
                    Button {
                        settings.menuBarDisplay = option
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: settings.menuBarDisplay == option
                                  ? "inset.filled.circle" : "circle")
                                .foregroundStyle(settings.menuBarDisplay == option
                                                 ? Color.accentColor : Color.secondary)
                            Text(option.label)
                            Spacer()
                            MenuBarPreviewChip(text: previewText(for: option))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if settings.budgetLimit > 0 || settings.dailyBudgetLimit > 0 {
                    Toggle("予算までの残りを表示", isOn: $settings.menuBarShowsRemaining)
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

    /// 各表示オプションでメニューバーに出る文字列。実データが無ければ "$–" を出す。
    /// 「予算までの残り」モードでは、予算のある項目を「残 上限 − 消費」に置き換える。
    private func previewText(for option: MenuBarDisplay) -> String? {
        let today = store?.todayCost.map { cost in
            settings.menuBarShowsRemaining && settings.dailyBudgetLimit > 0
                ? "残 " + PopoverView.money(settings.dailyBudgetLimit - cost)
                : PopoverView.money(cost)
        }
        let month = store?.budgetSpend.map { spend in
            settings.menuBarShowsRemaining && settings.budgetLimit > 0
                ? "残 " + PopoverView.money(settings.budgetLimit - spend)
                : PopoverView.money(spend)
        }
        switch option {
        case .iconOnly: return nil
        case .prompts: return "\(store?.today.prompts ?? 0)"
        case .cost: return today ?? "$–"
        case .monthlyCost: return month ?? "$–"
        case .bothCosts: return "\(today ?? "$–") · 月 \(month ?? "$–")"
        }
    }
}

/// メニューバーの見た目を模したプレビューチップ（⛽️ アイコン + タイトル）。
struct MenuBarPreviewChip: View {
    let text: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 10))
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
