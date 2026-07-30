import SwiftUI

/// 「Tokfuel について」ウィンドウ。バージョン・作者・謝辞（retok / Frankfurter）をまとめる。
/// retok の帰属表示（© Daiki Matsudate, MIT）はアプリ内のここに常設する。
struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .padding(.bottom, 4)
            Text("Tokfuel")
                .font(.title2.weight(.bold))
            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("AI のコストをメニューバーから一目で。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            Grid(alignment: .leadingFirstTextBaseline,
                 horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("作者")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Link("Dan Akiyama (@akidon0000)",
                         destination: URL(string: "https://github.com/akidon0000")!)
                }
                GridRow {
                    Text("ソースコード")
                        .foregroundStyle(.secondary)
                    Link("github.com/Tokfuel/Tokfuel",
                         destination: URL(string: "https://github.com/Tokfuel/Tokfuel")!)
                }
                GridRow {
                    Text("コスト分析")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Link("retok", destination: URL(string: "https://github.com/d-date/retok")!)
                        Text("© Daiki Matsudate (MIT License)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("為替レート")
                        .foregroundStyle(.secondary)
                    Link("Frankfurter API",
                         destination: URL(string: "https://frankfurter.dev")!)
                }
            }
            .font(.callout)

            Divider()
                .padding(.vertical, 8)

            Text("MIT License © akidon0000")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 320)
    }
}
