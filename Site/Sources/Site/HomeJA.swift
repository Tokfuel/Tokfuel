import Ignite

struct HomeJA: StaticPage {
    var path = "/ja"
    var title = "Tokfuel — AI コーディングのコストをメニューバーで"
    var description = "AI コーディングのコストを、メニューバーから。ローカルオンリーの小さな SwiftUI macOS アプリ。"

    var downloadURL = "https://github.com/Tokfuel/Tokfuel/releases/latest/download/Tokfuel-latest.dmg"
    var sourceURL = "https://github.com/Tokfuel/Tokfuel"
    var ownerURL = "https://github.com/Tokfuel"

    var body: some HTML {
        SiteChrome(language: .ja, topic: nil)

        Script(file: "\(sitePath)/js/budoux-ja.min.js")
        Script(file: "\(sitePath)/js/budoux-apply.js")
        Script(code: "(function(){var s=document.createElement('style');s.textContent='[data-budoux-root=\"true\"]{word-break:keep-all;overflow-wrap:anywhere;}';document.head.appendChild(s);}());")

        Section {
            VStack(alignment: .leading, spacing: 28) {
                Image("/images/app-icon.png", description: "Tokfuel のアプリアイコン")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)

                Text("Tokfuel")
                    .font(.title1)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("AI コーディングのコストを、メニューバーから。")
                    .font(.lead)
                    .foregroundStyle(Color(hex: "#A1A1A6"))
                    .frame(maxWidth: 560)

                Link("macOS 版をダウンロード", target: downloadURL)
                    .linkStyle(.button)
                    .role(.primary)

                Text("macOS 14 以降。無料のオープンソース。")
                    .font(.small)
                    .foregroundStyle(Color(hex: "#86868B"))
            }
            .padding(.vertical, 96)
            .padding(.horizontal, 32)
            .frame(maxWidth: 980)
            .attribute("data-budoux-root", "true")
        }
        .class("tf-hero")
        .foregroundStyle(.white)
        .horizontalAlignment(.leading)

        Section {
            Image("/images/screenshot.png", description: "コスト・予算・モデル別内訳を示す Tokfuel のメニューバーポップオーバー")
                .resizable()
                .cornerRadius(12)
                .frame(maxWidth: 720)
        }
        .padding(.vertical, 72)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)
        .class("tf-section-muted")

        Section {
            VStack(alignment: .leading, spacing: 20) {
                Text("仕組み")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("""
                Tokfuel は Claude Code・Codex CLI・Cursor が Mac 上に残すデータ \
                （~/.claude/projects/、~/.codex/sessions/、Cursor のローカルデータ）を \
                読むだけです。フックも追加セットアップも不要です。ソースは混ぜず、 \
                ラベル付きで扱います。利用データもプロンプトも Mac の外に出しません。 \
                数少ない通信（任意の為替レート、Cursor があるときの公開価格表・ \
                ダッシュボード API、アップデート確認、配布ビルドの Crashlytics と \
                同意時のみの Analytics）はプライバシーのページに列挙しています。
                """)
                .frame(maxWidth: 640)
                .foregroundStyle(.secondary)

                Link("ソースと詳細は GitHub で", target: sourceURL)
                    .linkStyle(.underline(.heavy))

                HStack(alignment: .center, spacing: 20) {
                    Link("ドキュメントを読む", target: "\(sitePath)/ja/docs/usage")
                        .linkStyle(.underline(.heavy))
                    Link("ロードマップ", target: "\(sitePath)/ja/docs/roadmap")
                        .linkStyle(.underline(.heavy))
                    Link("プライバシー", target: "\(sitePath)/ja/docs/privacy")
                        .linkStyle(.underline(.heavy))
                    Link("ADR 一覧", target: "\(sitePath)/ja/docs/adr")
                        .linkStyle(.underline(.heavy))
                    Link("テストと検証", target: "\(sitePath)/ja/docs/testing")
                        .linkStyle(.underline(.heavy))
                }
            }
            .padding(.vertical, 72)
            .padding(.horizontal, 32)
            .frame(maxWidth: 980)
            .attribute("data-budoux-root", "true")
        }
        .horizontalAlignment(.leading)

        Section {
            Text {
                "MIT License. © "
                Link("Tokfuel", target: ownerURL)
                    .linkStyle(.underline(.heavy))
            }
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)
        .class("tf-section-muted")
    }
}
