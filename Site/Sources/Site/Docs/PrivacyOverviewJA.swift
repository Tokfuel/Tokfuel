import Ignite

struct PrivacyOverviewJA: StaticPage {
    var path = "/ja/docs/privacy"
    var title = "プライバシー・通信ポリシー — Tokfuel"
    var description = "Tokfuel はローカルオンリー。数少ない通信の全リストとその理由。"
    var layout: DocsLayout { DocsLayout(page: .privacy, language: .ja) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("プライバシー・通信ポリシー").docsTitle()

            Text("""
            Tokfuel は Claude Code・Cursor・Codex CLI 由来の利用データ（プロンプト、 \
            トランスクリプト、コスト、パスなど）を Mac の外に一切出さない。例外は \
            下の一覧だけで、それ以外は無い。
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem {
                    Text {
                        Code("ExchangeRateService")
                        " — JPY 表示を有効にしたときだけ、1 日 1 回 "
                        Link("Frankfurter", target: "https://frankfurter.dev")
                        " から USD→JPY レートを取得する。リクエストに利用状況データは"
                        "載らない。"
                    }
                }
                ListItem {
                    Text {
                        Code("CursorPricingService")
                        " — Mac に Cursor を検出したときだけ、1 日 1 回 Cursor 自身が"
                        "公開する価格表を取得して Cursor のコスト推定を補正する。"
                        "利用状況データは送らず、価格を引けないモデルは当て推量ではなく"
                        "$0 として計上する。"
                    }
                }
                ListItem {
                    Text {
                        Code("CursorDashboardService")
                        " — Cursor がインストール済みでサインインもされていれば、"
                        "Cursor がローカルに保持済みのセッショントークンを使って "
                        "Cursor 自身のダッシュボード使用量 API を呼ぶ。リクエストに"
                        "載るのは認証ヘッダと日付範囲だけで、プロンプトやトランスクリプト"
                        "は送らない。失敗時はローカル SQLite のトークンスナップショット"
                        "へフォールバックする。"
                    }
                }
                ListItem {
                    Text {
                        Code("UpdateChecker")
                        " — 起動時と以後 24 時間ごとに、公開の GitHub Releases API を"
                        "ポーリングして新しいバージョンを検知する。リリースアセットの"
                        "ダウンロードはアップデートボタンを押したときだけ。これらの"
                        "リクエストに利用状況データ・トランスクリプト・識別子は載らない。"
                    }
                }
                ListItem {
                    Text("""
                    Firebase Crashlytics へのクラッシュレポート送信 — 配布ビルドのみ、 \
                    同意プロンプトなし、プロンプトやコストは含まない。開発ビルドでは \
                    Firebase を一切設定しない。
                    """)
                }
                ListItem {
                    Text("""
                    匿名の Firebase Analytics（アプリ UI イベント） — 配布ビルドかつ \
                    ユーザーが同意した場合のみ、デフォルトは OFF。
                    """)
                }
            }

            Text("""
            それ以外——コスト分析、予算、チャート、CSV 書き出し——はすべて、Claude \
            Code・Cursor・Codex CLI が Mac にすでに残しているファイルを読むだけで、 \
            端末上で完結する。
            """)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("プライバシーポリシー", target: "https://github.com/Tokfuel/Tokfuel/blob/main/Docs/PRIVACY.ja.md")
                    .linkStyle(.underline(.heavy))
                Link("利用規約", target: "https://github.com/Tokfuel/Tokfuel/blob/main/Docs/TERMS.ja.md")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
