import Ignite

struct TestingJA: StaticPage {
    var path = "/ja/docs/testing"
    var title = "テストと検証 — Tokfuel"
    var description = "App/Tests の構成、UnitTests がカバーする領域、検証ゲート、CI、UI プレビューの約束。"
    var layout: DocsLayout { DocsLayout(page: .testing, language: .ja) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("テストと検証").docsTitle()

            Text("""
            アプリ向けの検証物はすべて App/Tests/ 配下にまとめます（ADR-0001）。 \
            実行するユニットテストと、結合・通し・シナリオ設計の箱を同じ親の下に置き、 \
            製品コード（App/Tokfuel*）と運営物（Site / Docs / Scripts）を分けます。 \
            このページに、配置の意味と検証の進め方を載せます。
            """)
            .foregroundStyle(.secondary)

            Text("ディレクトリ構成").docsSubheading()

            CodeBlock {
                """
                App/Tests/
                  UnitTests/          … Swift Testing。swift test の対象
                  IntegrationTests/   … 結合テスト（いまは箱のみ）
                  E2E/                … 通し実装（swift test 対象外）
                  TestDocs/           … シナリオ設計（実行しない文書）
                  README.md           … 親ディレクトリの説明
                """
            }

            Text("UnitTests").fontWeight(.bold)

            Text("""
            ヘッドレスで検証できるロジックをここに置きます。Package.swift の TokfuelTests \
            がこのパスを指し、swift test で実行します。新しいロジックを足したら、同じ層の \
            近くにテストを足します。
            """)
            .foregroundStyle(.secondary)

            Text("実ユーザーの状態（~/Library/Application Support/Tokfuel）に触れるテストは書きません。")
                .foregroundStyle(.secondary)

            CoverageChart(language: .ja)

            Text("IntegrationTests").fontWeight(.bold)

            Text("""
            結合テスト用の箱です。いまは README だけのプレースホルダです。追加するときは \
            別の test target を切るか Package.swift に明示的に足し、既定の UnitTests パスには \
            混ぜません。
            """)
            .foregroundStyle(.secondary)

            Text("E2E").fontWeight(.bold)

            Text("""
            通しテスト実装の置き場です。swift test の対象外で、別ランナーを想定します。 \
            Maestro や Appium などのモバイル向けスタックは持ち込みません。macOS \
            メニューバーアプリ向けの起動スモークや画面到達など、必要な範囲だけを後続 Issue で \
            足します。シナリオ設計の正本は TestDocs 側です。
            """)
            .foregroundStyle(.secondary)

            Text("TestDocs").fontWeight(.bold)

            Text("""
            テストシナリオ設計を置く場所です。実行コードではありません。観点の正本をここに \
            置き、起票 → 実装 → ステータス更新の流れで進めます。テンプレートや観点 ID の規約、 \
            個別シナリオは後続 Issue で足す前提で、配置の箱を先に確保しています。
            """)
            .foregroundStyle(.secondary)

            Text("UnitTests がカバーしている領域").docsSubheading()

            Text("Store / 合算・表示整形").fontWeight(.bold)
            List {
                ListItem { Text("UsageStore — 合計、チャート、モデル別内訳の保持と更新") }
                ListItem { Text("CostChart / CostDisplayMode / Formatting — 表示用の整形とモード") }
                ListItem { Text("MenuBarReadout / MenuBarImage — メニューバーの読み出しと描画") }
                ListItem { Text("RefreshScheduler — 待機時とアクティブ時の更新間隔") }
            }

            Text("Claude（retok）").fontWeight(.bold)
            List {
                ListItem { Text("RetokReport — レポートのデコード") }
                ListItem { Text("TranscriptScanner — トランスクリプト走査") }
                ListItem { Text("AdvicePrompt — 節約ヒント用プロンプト") }
            }

            Text("Cursor / Codex").fontWeight(.bold)
            List {
                ListItem { Text("CursorDashboardService / CursorPricing / CursorPricingService — ダッシュボード取得と価格表") }
                ListItem { Text("CursorCostDriver / CursorAdvice — コスト推定とアドバイス") }
                ListItem { Text("CodexCostDriver — Codex CLI セッション由来のコスト") }
            }

            Text("Budget / Settings / その他").fontWeight(.bold)
            List {
                ListItem { Text("BudgetMonitor — 月次・日次しきい値と一度きりの通知") }
                ListItem { Text("AppSettings — UserDefaults ベースの設定") }
                ListItem { Text("CSVExportService — 端末上だけの CSV 書き出し") }
                ListItem { Text("UpdateChecker — Releases ポーリングとダウンロード境界") }
                ListItem { Text("HTTPClient / RemoteDiagnosticsPolicy / UsageEventLog — 通信と診断ポリシー") }
                ListItem { Text("ScreenshotRenderer — ui-preview 用フィクスチャ画面の描画") }
            }

            Text("ローカルでの検証ゲート").docsSubheading()

            List {
                ListItem {
                    Text {
                        Code("swift test")
                        " — App/Tests/UnitTests を実行する。PR 前の基本ゲート。"
                    }
                }
                ListItem {
                    Text {
                        Code("swift build -c release")
                        " — Scripts/build.sh がパッケージする構成に近いリリースビルド。"
                    }
                }
                ListItem {
                    Text {
                        Code("bash Scripts/build.sh")
                        " — Tokfuel.app を /Applications に配置して起動し、実行時に見える変更を観察する。"
                        "未検証の動作を動くと主張しない。"
                    }
                }
            }

            Text("CI").docsSubheading()

            Text("""
            .github/workflows/ci.yml が、App/Tokfuel・App/Tests・Package.swift などを触った \
            PR でユニットテストを実行します。Docs / Site のみの変更ではそのジョブは走りません。 \
            リリース構成のビルドは Scripts/build.sh や配布フロー側で確認します。
            """)
            .foregroundStyle(.secondary)

            Text("UI プレビュー（スクリーンショット）").docsSubheading()

            Text("""
            レビュアーが新しい UI を見られないままにしないための約束です。PopoverView、 \
            SettingsView、AboutView、および単独で見せる新規 View（同意ダイアログやアラートなど）を \
            追加または変更するときは、同じ PR で次も更新します。
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem { Text("ScreenshotRenderer.allScreens() のフィクスチャ画面") }
                ListItem { Text("ui-preview.yml の ORDER / screen_title リスト") }
            }

            Text("""
            ui-preview ラベルが付いた PR では、新しい状態を実際に描画できます。ライブな \
            シングルトン経由でしか到達できないビュー（ネットワーク応答や実インストールパスに \
            依存するもの）には、注入可能なフィクスチャを用意します（UpdateChecker.preview など）。 \
            ダイアログやパネルの文面は SwiftUI の表示 View に置き、ランタイムとプレビューで \
            同じ View を使います。
            """)
            .foregroundStyle(.secondary)

            Text("担保の優先").docsSubheading()

            Text("""
            ヘッドレスで足りるロジックは UnitTests を先に足します。画面の見た目や到達は \
            ui-preview（VRT 相当）と、必要な範囲の E2E で補います。シナリオの「何を担保するか」は \
            TestDocs に書き、実装は UnitTests / IntegrationTests / E2E に振り分けます。
            """)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("ADR-0001（このサイト）", target: "\(sitePath)/ja/docs/adr")
                    .linkStyle(.underline(.heavy))
                Link("アーキテクチャ", target: "\(sitePath)/ja/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("App/Tests/（git）", target: "https://github.com/Tokfuel/Tokfuel/tree/main/App/Tests")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
