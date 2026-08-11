import Ignite

struct ADRIndexJA: StaticPage {
    var path = "/ja/docs/adr"
    var title = "ADR 一覧 — Tokfuel"
    var description = "Tokfuel のアーキテクチャ決定。ADR-0001 / 0002 の決定内容、比較検討、結果をサイト上で読む。"
    var layout: DocsLayout { DocsLayout(page: .adr, language: .ja) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("ADR 一覧").docsTitle()

            Text("""
            ADR（Architecture Decision Record）は、技術的な意思決定を Issue や会話に \
            散らさず残す短い記録です。「なぜその形にしたか」をあとから追えるようにします。 \
            下のトグルを開いて、決定・背景・比較・結果を読んでください。git 上の ADR/ が \
            日英の正本で、ずれたときは日本語を正とします。
            """)
            .foregroundStyle(.secondary)

            Text("一覧").docsSubheading()

            List {
                ListItem {
                    Text("0001 — アプリ関連を App/ 配下に集約する · Accepted · Issue #134")
                }
                ListItem {
                    Text("0002 — SPM を UI / Store / sources のレイヤーで分割する · Proposed · Issue #109")
                }
            }

            // MARK: ADR-0001

            Text("ADR-0001：アプリ関連を App/ 配下に集約する").docsSubheading()

            Text("Accepted · 2026-08-08 · Site は対象外 · 配置のみ、挙動は変えない")
                .font(.small)
                .foregroundStyle(.secondary)
                .class("tf-adr-status")

            Accordion {
                Item("決定事項", startsOpen: true) {
                    Text("""
                    アプリ本体と検証物の置き場を、次の木に固定します。ディレクトリ名も変えます。 \
                    Sources / Tests のままだと「リポジトリ全体のソース」にも読め、スコープが曖昧になるためです。
                    """)
                    .foregroundStyle(.secondary)

                    CodeBlock {
                        """
                        App/
                          Tokfuel*          … executable と各 library（旧 Tokfuel/Sources）
                          Tests/
                            UnitTests/      … swift test の対象
                            IntegrationTests/ … 結合（後続）
                            TestDocs/       … シナリオ設計（実行しない）
                            E2E/            … 通し実装（swift test 対象外）
                        """
                    }

                    Text("""
                    製品コードの木と、Site / Docs / Scripts などの運営物をディレクトリで分けます。 \
                    TestDocs と E2E も同じ App/ の下に足せるようにします。
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("背景と課題") {
                    Text("""
                    以前は本体が Tokfuel/Sources、テストが Tokfuel/Tests にあり、単一 SPM target から \
                    参照していました。シナリオ設計と通しテストをリポジトリに載せる必要が出たとき \
                    （#134）、トップレベルや別ツリーに置くと入口が増え続けます。
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("置き場がばらけると、「どこを触るか」を毎回探し、無関係な変更が同じ PR に混ざりやすい。") }
                        ListItem { Text("TestDocs / E2E の親を先に決めないと、後から別慣習が生え、モジュール分割と噛み合わせにくい。") }
                        ListItem { Text("ルートや Tokfuel/Sources という名前は、アプリ製品の木だと一目で分からない。") }
                    }
                }

                Item("比較した案") {
                    List {
                        ListItem { Text("案1 現状維持 — TestDocs / E2E は都度別場所。ばらけ方と後続箱の課題が残る（不採用）。") }
                        ListItem { Text("案2 トップレベルに並べる — 入口は揃うが Site / Docs と同じ階層で混ざる（不採用）。") }
                        ListItem { Text("案3 App/ 配下に集約 — アプリ関連の親が一つ。Site は外に置いたまま（採用）。") }
                    }

                    Text("""
                    探索しやすさ、TestDocs / E2E の伸ばしやすさ、#109（モジュール分割）との両立で \
                    案3が優れます。移行はパス更新が必要ですが、挙動変更は不要です。
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("結果") {
                    List {
                        ListItem { Text("アプリ関連の探索入口が App/ に一つになる。") }
                        ListItem { Text("運営物と製品コードの境界がディレクトリで分かる。") }
                        ListItem { Text("後続のモジュール分割を「アプリの中」の話として切りやすい。") }
                    }

                    Text("""
                    版正本の置き場やトップレベル改名まではこの決定に含めません。App/ 集約だけの範囲に \
                    閉じます。詳細な比較表はリポジトリの ADR 本文にあります。
                    """)
                    .foregroundStyle(.secondary)
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            // MARK: ADR-0002

            Text("ADR-0002：SPM を UI / Store / sources のレイヤーで分割する").docsSubheading()

            Text("Proposed · 2026-08-08 · 前提 ADR-0001 · target 境界（木の再配置ではない）")
                .font(.small)
                .foregroundStyle(.secondary)
                .class("tf-adr-status")

            Accordion {
                Item("決定事項", startsOpen: true) {
                    Text("""
                    App/ 配下の単一 SPM target をやめ、レイヤーで library target を分割します。 \
                    データの流れと依存の向きを次で固定します。
                    """)
                    .foregroundStyle(.secondary)

                    CodeBlock {
                        """
                        sources（Claude / Cursor / Codex / Budget …）  … 取得。情報を取る API を公開
                                ↓
                        Store                                         … 機能名ファイルごとに UI 向けへ整形・合算
                                ↓
                        UI                                            … Store が渡す情報を表示

                        依存の向き: UI → Store → sources
                        具象の組み立て: App（executable）
                        """
                    }

                    List {
                        ListItem { Text("sources は取得軸で分ける。横断型だけ薄い TokfuelCore に置く。") }
                        ListItem { Text("Store はソース固有の整形を機能名ファイル（例: CursorUsage.swift）に分け、UI へ渡す形にまとめる。") }
                        ListItem { Text("UI は Store（と表示に必要な薄い型）だけを見る。SQLite、retok、ダッシュボード API を直接見ない。") }
                        ListItem { Text("Firebase、retok リソース、sqlite3 は、使う source / Analytics target に閉じる。") }
                        ListItem { Text("挙動とグラウンドルール（ローカルオンリー、ゼロセットアップ、retok 無改変、python3 任意、新規パッケージ禁止）は変えない。") }
                    }

                    Text("""
                    feature 縦割り（UI 片まで各ソースに閉じる）は採りません。変更の自然な切れ目が \
                    「取得 → 整形 → 表示」だからです。sources を Claude / Cursor などに分けるのは \
                    レイヤーの下段の話であり、UI / Store をソース縦割りにはしません。
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("変更の置き場の例") {
                    List {
                        ListItem {
                            Text("Cursor の今日分コストを直す — 取得は TokfuelCursor、整形は Store の Cursor 用ファイル、見た目だけなら TokfuelUI。")
                        }
                        ListItem {
                            Text("ポップオーバーの余白や共通レイアウト — TokfuelUI に閉じる。データが変わらないなら Store / sources は触らない。")
                        }
                        ListItem {
                            Text("データの流れ（Cursor 行）— Cursor が取る → Store が整形 → UsageStore 相当が合算 → PopoverView 相当が表示。")
                        }
                    }
                }

                Item("背景と課題") {
                    Text("""
                    ADR-0001 で親を App/ に揃えたあとも、target は一つで、UI・Store・外部通信・コスト計算が \
                    同一ディレクトリに混在していました（#109）。並行 PR の衝突を減らす feature 縦割りも \
                    比べましたが、実データの流れは「sources が取り、Store が整形して UI に渡す」形であり、 \
                    UI を横串で直したい変更も残ります。その切れ目に合わせると境界はレイヤーになります。
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("Store / UI / driver の役割分担が文書依存で、コンパイルでは守れない。") }
                        ListItem { Text("取得・整形・表示のどこを直すかが、ディレクトリ名から読み取りにくい。") }
                        ListItem { Text("見た目の横断修正とソース固有の取得修正が、同じ木で交差しやすい。") }
                    }
                }

                Item("比較した案") {
                    List {
                        ListItem { Text("案1 現状維持 — 境界と見通しの課題が残る（不採用）。") }
                        ListItem { Text("案2 レイヤー — データの流れと UI 横断に合う。sources は下段で分割（採用）。") }
                        ListItem { Text("案3 feature 縦割り — ソース衝突には効くが、UI をまとめて直す軸と相性が悪い（不採用）。") }
                        ListItem { Text("案4 極細レイヤー多数 — きれいさに対してコストが過大（不採用）。") }
                        ListItem { Text("案5 ハイブリッド — 縦と層が二重になり、境界管理が重い（不採用）。") }
                    }
                }

                Item("結果とリスク") {
                    List {
                        ListItem { Text("UI が SQLite や retok 実装を直接見ない、といった逆流をコンパイルで検知できる。") }
                        ListItem { Text("「取得は Cursor target」「整形は Store の Cursor ファイル」「見た目は UI」と変更範囲を説明しやすい。") }
                        ListItem { Text("Store / UI は層としてホットスポットになりうる — 機能名ファイルと画面単位ファイルに分け、PR を小さく保つ。") }
                        ListItem { Text("逆依存（BudgetMonitor→UI など）は target を切る前に callback / プロトコル化でほどく。") }
                    }
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            // MARK: process

            Text("書き方と状態").docsSubheading()

            Accordion {
                Item("書式と状態", startsOpen: true) {
                    Text("""
                    1 件の決定 = 1 ディレクトリ。本文ファイル名はディレクトリ名と同じ ID-slug です。 \
                    日本語（.ja.md）と英語（.md）の両方が必須です。本文は Decision / Context / \
                    Consideration / Consequences / References の 5 セクションで、Consideration には \
                    現状維持を必ず含めます。
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("Accepted — いま有効な決定") }
                        ListItem { Text("Proposed / Draft — 検討中・レビュー待ち") }
                        ListItem { Text("Deprecated / Superseded / Rejected — 履歴として残すもの") }
                    }

                    Text("""
                    大きな方針変更は、先に GitHub Issue（ラベル ADR）で議論し、合意した内容を ADR に \
                    落とします。新規 ADR を足したり状態を変えたら、同じ PR で INDEX も更新します。
                    """)
                    .foregroundStyle(.secondary)
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            HStack(spacing: 16) {
                Link("アーキテクチャ", target: "\(sitePath)/ja/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("テストと検証", target: "\(sitePath)/ja/docs/testing")
                    .linkStyle(.underline(.heavy))
                Link("ADR/（git 正本）", target: "https://github.com/Tokfuel/Tokfuel/tree/main/ADR")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
        .class("tf-adr")
        .attribute("data-budoux-root", "true")
    }
}
