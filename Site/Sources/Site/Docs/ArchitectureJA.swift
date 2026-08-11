import Ignite

struct ArchitectureJA: StaticPage {
    var path = "/ja/docs/architecture"
    var title = "アーキテクチャ — Tokfuel"
    var description = "UI → Store → sources の SPM レイヤーと、UsageStore・各ソースの役割。"
    var layout: DocsLayout { DocsLayout(page: .architecture, language: .ja) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("アーキテクチャ").docsTitle()

            Text("""
            Tokfuel はサーバーを持たない SwiftUI 製のメニューバーアプリ。表示する \
            数字はすべて、Claude Code・Cursor・Codex CLI が Mac にすでに残している \
            ファイルを読み取って作られる。
            """)
            .foregroundStyle(.secondary)

            Text("SPM レイヤー").docsSubheading()

            Text("""
            アプリ本体は App/ 配下の複数 SPM target に分かれる。依存の向きは \
            UI → Store → sources。executable（Tokfuel）が具象を組み立てる。
            """)
            .foregroundStyle(.secondary)

            Section {
                Include("architecture.svg")
            }
            .class("tf-arch-diagram")
            .attribute("aria-label", "Tokfuel の SPM レイヤー図")

            List {
                ListItem {
                    Text {
                        Code("TokfuelUI")
                        " — ポップオーバー・設定・About など表示"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelStore")
                        " — 合算と UI 向け整形（"
                        Code("UsageStore")
                        "）"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelClaude")
                        " / "
                        Code("TokfuelCursor")
                        " / "
                        Code("TokfuelCodex")
                        " / "
                        Code("TokfuelBudget")
                        " — 取得・判定などの sources"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelSettings")
                        " / "
                        Code("TokfuelAnalytics")
                        " / "
                        Code("TokfuelCore")
                        " — 設定、任意の Analytics、横断型"
                    }
                }
            }

            Text {
                "データの流れは取得 → 整形・合算 → 表示。決定の正本は "
                Link("ADR-0002", target: "https://github.com/Tokfuel/Tokfuel/blob/main/ADR/0002-layer-spm-modules/0002-layer-spm-modules.ja.md")
                "。リポジトリ README にも同じ依存図がある。"
            }
            .foregroundStyle(.secondary)

            Text("UsageStore：唯一の情報源").docsSubheading()

            Text("""
            UsageStore（TokfuelStore）は全ビューが参照する唯一の @MainActor オブジェクト。 \
            現在のコスト合計・チャート・モデル別内訳を保持し、タイマーで更新する（待機中は \
            10 分ごと、コストが動くと 5 分間だけ 1 分ごとに切り替わる）。 \
            PopoverView など UI 側は純粋な表示層のままで、設定は AppSettings \
            （UserDefaults ベース）に分離している。
            """)
            .foregroundStyle(.secondary)

            Text("RetokService：Claude Code 自身のトランスクリプトを読む").docsSubheading()

            Text {
                "RetokService（TokfuelClaude）は同梱の "
                Link("retok", target: "https://github.com/Tokfuel/Tokfuel/blob/main/App/TokfuelClaude/Resources/README-retok.md")
                "（© Daiki Matsudate、MIT、無改変で同梱）を呼び出し、Claude Code が "
                "自分で書き出す "
                Code("~/.claude/projects/")
                " のトランスクリプトを解析する。フックも追加インストールも設定も不要。"
                "python3 は任意の依存で、無くてもコスト分析だけが縮退し、他の機能は"
                "動き続ける。"
            }
            .foregroundStyle(.secondary)

            Text("BudgetMonitor").docsSubheading()

            Text("""
            BudgetMonitor（TokfuelBudget）は UsageStore の合計値を AppSettings の月次・日次の \
            上限と突き合わせ、しきい値を超えるたびに一度だけ知らせる。アラートウィンドウの \
            表示は App / UI 側が組み立てる。
            """)
            .foregroundStyle(.secondary)

            Text("ソース別の Service").docsSubheading()

            List {
                ListItem {
                    Text {
                        Code("CursorDashboardService")
                        " — Cursor がインストール済みでサインインもされていれば、"
                        "Cursor が state.vscdb に保持済みのセッショントークンを使って "
                        "Cursor 自身のダッシュボード使用量 API を呼ぶ。サインアウトや "
                        "オフライン時はローカル SQLite のトークンスナップショットへ "
                        "フォールバックする。"
                    }
                }
                ListItem {
                    Text {
                        Code("CursorPricingService")
                        " — Cursor 自身が公開する価格表を 1 日 1 回取得し、"
                        "フォールバック経路の利用を補正する。価格を引けないモデルは "
                        "当て推量のレートではなく $0 として計上する。"
                    }
                }
                ListItem {
                    Text {
                        Code("ExchangeRateService")
                        " — JPY 表示を有効にしたときだけ、Frankfurter から USD→JPY "
                        "レートを 1 日 1 回取得する。"
                    }
                }
                ListItem {
                    Text {
                        Code("UpdateChecker")
                        " — 起動時と以後 24 時間ごとに GitHub Releases をポーリングし、"
                        "新しいバージョンを検知する。リリースアセットのダウンロードは "
                        "アップデートボタンを押したときだけ。"
                    }
                }
                ListItem {
                    Text {
                        Code("CSVExportService")
                        " — retok レポートにすでにある当該期間のデータを、端末上だけで"
                        "日次・月次 CSV に変換する。"
                    }
                }
                ListItem {
                    Text {
                        Code("AnalyticsService")
                        " — オプトイン・配布ビルド限定の Firebase Analytics イベント"
                        "送信を一元化する窓口。それ以外のビルドでは何もしない。"
                    }
                }
            }

            Text("""
            各ソースは独立に扱い、ラベル付きで区別する。Cursor や Codex のコストが \
            ラベルなしで Claude の合計に混ざることはない。
            """)
            .foregroundStyle(.secondary)

            Text("App/ の木").docsSubheading()

            Text("""
            ADR-0001 により、アプリ関連は App/ 配下に集約する。Site・Docs・Scripts は \
            対象外。検証物は App/Tests/ にまとめ、本体の SPM レイヤー（App/Tokfuel*）と \
            並べる。
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem {
                    Text {
                        Code("App/Tokfuel*")
                        " — executable と各 library（UI / Store / sources）"
                    }
                }
                ListItem {
                    Text {
                        Code("App/Tests/UnitTests")
                        " — "
                        Code("swift test")
                        " の対象"
                    }
                }
                ListItem {
                    Text {
                        Code("App/Tests/{IntegrationTests,E2E,TestDocs}")
                        " — 結合・通し・シナリオ設計（役割はテストページを参照）"
                    }
                }
            }

            Text("関連ドキュメント").docsSubheading()

            HStack(spacing: 16) {
                Link("ADR 一覧", target: "\(sitePath)/ja/docs/adr")
                    .linkStyle(.underline(.heavy))
                Link("テストと検証", target: "\(sitePath)/ja/docs/testing")
                    .linkStyle(.underline(.heavy))
                Link("GitHub で App/ を見る", target: "https://github.com/Tokfuel/Tokfuel/tree/main/App")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
