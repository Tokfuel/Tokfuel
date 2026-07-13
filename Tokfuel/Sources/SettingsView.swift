import SwiftUI
import AppKit

/// 初期設定を行うウィンドウ。ログイン起動・メニューバー表示・期間・言語・スキャン場所を切り替える。
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

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
                Picker("表示内容", selection: $settings.menuBarDisplay) {
                    ForEach(MenuBarDisplay.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
            }

            Section("集計") {
                Picker("既定の集計期間", selection: $settings.defaultPeriodDays) {
                    Text("7 日").tag(7)
                    Text("30 日").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Picker("レポート言語", selection: $settings.language) {
                    ForEach(ReportLanguage.allCases) { Text($0.label).tag($0) }
                }
            }

            Section {
                HStack {
                    Text("上限金額 (USD)")
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
                Text("しきい値に達するとメニューバーのアイコンがオレンジになり通知します。上限を超えると赤になります。0 を設定すると予算機能はオフです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                PathRow(title: "Claude ディレクトリ",
                        note: "tool の集計元 (projects) と skill / plugin の読み取り元",
                        path: $settings.claudeDirectory,
                        defaultPath: AppSettings.defaultClaudeDirectory)
                PathRow(title: "リポジトリルート",
                        note: "プロジェクト単位の skill (.claude/skills) を探すルート",
                        path: $settings.repositoryRoot,
                        defaultPath: AppSettings.defaultRepositoryRoot)
            } header: {
                Text("スキャン場所")
            } footer: {
                Text("トランスクリプトを直接読み取ります。フックや追加設定は不要です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $settings.serverQuotaEnabled) {
                    Text("サーバーの正確な使用率を取得")
                    Text("公式 /usage と同じ 5 時間・週次の消費率を Cost タブに表示します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("サーバークォータ（オプトイン）")
            } footer: {
                Text("有効にすると、Claude Code が保存済みの認証トークンだけを Anthropic の API に送って使用率を取得します（本アプリ唯一の通信機能）。使用データや個人情報は送信しません。トークンの更新はせず、失効時は Claude Code を開くと直ります。初回は Keychain へのアクセス許可を求められることがあります。")
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
