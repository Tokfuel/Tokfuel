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
            Text("Claude Code のコストをメニューバーから一目で。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent {
                    Link("Dan Akiyama (@akidon0000)",
                         destination: URL(string: "https://github.com/akidon0000")!)
                } label: {
                    Text("作者")
                }

                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Link("retok", destination: URL(string: "https://github.com/d-date/retok")!)
                        Text("© Daiki Matsudate (MIT License)")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("コスト分析")
                }

                LabeledContent {
                    Link("Frankfurter API",
                         destination: URL(string: "https://frankfurter.dev")!)
                } label: {
                    Text("為替レート")
                }
            }
            .font(.callout)

            Divider()
                .padding(.vertical, 8)

            Text("MIT License © akidon0000 — ただし同梱の retok は上記の通り。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 320)
    }
}
