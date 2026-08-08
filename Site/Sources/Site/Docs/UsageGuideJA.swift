import Ignite

struct UsageGuideJA: StaticPage {
    var path = "/ja/docs/usage"
    var title = "使い方ガイド — Tokfuel"
    var description = "Tokfuel のインストール方法と、表示される内容の読み方。"
    var layout: DocsLayout { DocsLayout(page: .usage, language: .ja) }

    var body: some HTML {
        VStack(spacing: 24) {
            Text("使い方ガイド").docsTitle()

            Text("インストール").docsSubheading()

            List {
                ListItem {
                    Text {
                        "ダウンロードページか "
                        Link("GitHub Releases", target: "https://github.com/Tokfuel/Tokfuel/releases/latest")
                        " から Tokfuel-x.y.z.dmg を取得する。"
                    }
                }
                ListItem { Text("開いて Tokfuel.app を Applications にドラッグする。") }
                ListItem {
                    Text("""
                    起動する — リリースは Developer ID 署名・Apple の公証済みなので \
                    Gatekeeper の警告なしに開く。
                    """)
                }
            }
            .listMarkerStyle(.ordered)

            Text("""
            macOS 14 以降と、コスト分析用の python3（Xcode Command Line Tools に \
            同梱済み）が必要。python3 が無い場合はコスト分析だけが緩やかに縮退し、 \
            それ以外の機能は動き続ける。
            """)
            .foregroundStyle(.secondary)

            Text("メニューバーの見方").docsSubheading()

            Text("""
            ⛽️ アイコンは今日または今月のコスト、パーセント、リングゲージのいずれかを \
            表示する（設定で選択）。予算のしきい値に近づくとオレンジ、超えると赤に \
            変わる。クリックするとポップオーバーが開き、現在のコスト、今日／今週／ \
            今月／今年の推移チャート、モデル別内訳、高コストのセッション、節約の \
            ヒント（retok の Claude 分析と Cursor 由来のもの）が見られる。
            """)
            .foregroundStyle(.secondary)

            Text("予算").docsSubheading()

            Text("""
            設定で月次・日次の上限を独立に設定できる。しきい値に近づくと、 \
            通知・フローティングアラートウィンドウ・両方のいずれかで一度だけ \
            知らせる。
            """)
            .foregroundStyle(.secondary)

            Text("Cursor と Codex").docsSubheading()

            Text("""
            Cursor がインストール済みでサインインもされていれば、今日の Cursor \
            利用は Cursor 自身のダッシュボード API 経由で同じ合計・チャートに \
            折り込まれる。サインアウトまたはオフラインのときはローカルの \
            トークンスナップショットにフォールバックし、その旨を表示するので \
            $0 表示が「未使用」と誤解されることはない。Codex CLI のローカル \
            セッションログがあれば、そのコストは日次チャートで別の色として \
            表示され、Claude の合計には混ざらない。設定では、合算 / Claude \
            のみ / Cursor のみ / Codex のみ / 並列表示を選べる。
            """)
            .foregroundStyle(.secondary)

            Text("利用状況のエクスポート").docsSubheading()

            Text("""
            ポップオーバーの ⋯ メニューから、表示中の期間の日次・月次 CSV を \
            書き出せる。期間合計とモデル別コスト内訳も含む。チームの利用額を \
            手動で集計する管理者向けで、それ自体が外部に送信されることはない。
            """)
            .foregroundStyle(.secondary)

            Link("GitHub で機能一覧の全文を見る", target: "https://github.com/Tokfuel/Tokfuel#-features")
                .linkStyle(.underline(.heavy))
        }
        .frame(maxWidth: 720)
    }
}
