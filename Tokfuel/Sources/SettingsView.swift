import SwiftUI
import AppKit

/// 初期設定を行うウィンドウ。ログイン起動・メニューバー表示・期間・言語・スキャン場所を切り替える。
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    /// メニューバー表示のプレビューに実データを出すためのストア（省略時はプレースホルダ表示）。
    var store: UsageStore?

    var body: some View {
        Form {
            Section("一般") {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("ログイン時に自動起動")
                    Text("Mac 起動時にメニューバーへ常駐します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("メニューバー表示") {
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
            }

            Section {
                Picker("既定の集計期間", selection: $settings.defaultPeriodDays) {
                    Text("7 日").tag(7)
                    Text("30 日").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Picker("レポート言語", selection: $settings.language) {
                    ForEach(ReportLanguage.allCases) { Text($0.label).tag($0) }
                }

                Picker("表示通貨", selection: $settings.displayCurrency) {
                    ForEach(DisplayCurrency.allCases) { Text($0.label).tag($0) }
                }
            } header: {
                Text("集計")
            } footer: {
                Text("日本円を選ぶと Frankfurter API から為替レートを 1 日 1 回取得します（送るのはレートの問い合わせだけで、使用データは含みません）。予算の上限は USD のまま入力します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("月の上限 (USD)")
                    Spacer()
                    TextField("0 = オフ", value: $settings.budgetLimit, format: .number)
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
                    Text("1日の上限 (USD)")
                    Spacer()
                    TextField("0 = オフ", value: $settings.dailyBudgetLimit, format: .number)
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
                Text("月と 1 日の上限は独立に設定できます。どちらかがしきい値に達するとメニューバーのアイコンがオレンジになり通知します。上限を超えると赤になります。0 を設定するとその予算はオフです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                PathRow(title: "Claude ディレクトリ",
                        note: "コスト集計元のトランスクリプト (projects) の読み取り元",
                        path: $settings.claudeDirectory,
                        defaultPath: AppSettings.defaultClaudeDirectory)
            } header: {
                Text("スキャン場所")
            } footer: {
                Text("トランスクリプトを直接読み取ります。フックや追加設定は不要です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $settings.eventLogEnabled) {
                    Text("利用イベントを記録")
                    Text("タブ切り替えなど Tokfuel 自身の操作イベントだけを記録します")
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
            } header: {
                Text("イベントログ")
            } footer: {
                Text("記録は常にこの Mac の中だけに保存され、外部には送信されません。トランスクリプトの内容・プロジェクト名・コストは記録しません。機能改善の判断（ロードマップ提案・実験）に使います。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("謝辞") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("コスト分析エンジン: retok")
                        Spacer()
                        Link("GitHub", destination: URL(string: "https://github.com/d-date/retok")!)
                            .font(.caption)
                    }
                    Text("© Daiki Matsudate (@d-date) — MIT License。本アプリは retok を無改変で同梱し、コスト・キャッシュ効率・改善提案の算出に利用しています。ライセンス全文はアプリ内の LICENSE-retok を参照。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 720)
    }

    /// 各表示オプションでメニューバーに出る文字列。実データが無ければ "$–" を出す。
    private func previewText(for option: MenuBarDisplay) -> String? {
        let today = store?.todayCost.map(PopoverView.money)
        let month = store?.budgetSpend.map(PopoverView.money)
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
