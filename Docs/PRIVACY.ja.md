# Tokfuel プライバシーポリシー

*最終更新: 2026-07-31*

このポリシーは、macOS アプリ Tokfuel がどのデータを読み取り、保存し、送信するかを説明します。Tokfuel の利用者と App Store 審査に向けた文書です。

## 要約

Tokfuel は個人アカウントを持たず、プロンプトやローカルの transcript を送信しません。Claude Code / Cursor / Codex から読み取った利用データは、原則として Mac の中にとどまります。配布ビルドでは、クラッシュレポートを Firebase Crashlytics へ送ります。利用状況アナリティクス（Firebase Analytics）は、設定で明示的に許可した場合だけ送ります。そのほか、為替レート、GitHub Releases への更新確認、Cursor 利用時の価格表とダッシュボード利用量など、限定的で開示済みの通信があります。

## アプリがローカルで読み取るデータ

Claude Code の利用状況を可視化するため、Tokfuel は Claude Code がすでに Mac 上に書き出しているファイルを読み取ります。

- **transcript**（`~/.claude/projects/` 以下）：Claude Code のコスト、プロンプト数、セッション数の算出に端末上で使います。
- **Cursor のローカルトークンデータベース**（`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`、Cursor 導入時のみ）：Cursor のコスト見積りに使います。このファイルは端末上でのみ読み取ります。認証トークンと日付範囲が外部に送信されるケースは下記のみです。
- **Codex CLI のセッションログ**（`~/.codex/sessions/` 以下、存在する場合）：同梱の retok スクリプト経由で端末上でのみ読み取り、セッション数・トークン数に加えて Codex のコストを見積ります。Claude の合計には合算せず、別建ての見積りとして扱います。

処理はすべて端末上で行います。集計結果や設定、通知の状態といった派生データは `~/Library/Application Support/Tokfuel/` とアプリのユーザーデフォルトにのみ保存し、Firebase へ送る対象にはしません。

現時点で Tokfuel が読み取るのは Claude Code、Cursor、Codex のローカルファイルです。将来のバージョンで他の AI コーディングツールへの対応を追加する場合も、同様にそれらのローカルファイルを端末上でのみ処理し、対応時にはこのポリシーを更新して対象ツールを明記します。

## 通信

Tokfuel が通信するのは以下のケースのみで、Claude Code の transcript やプロンプトを送信することはありません。

- **為替レート（オプトイン）**：表示通貨を日本円に切り替えると、[Frankfurter API](https://frankfurter.dev)（`api.frankfurter.dev`）から USD→JPY の為替レートを 1 日 1 回まで取得します。利用データ、識別子、Mac 上のコンテンツは一切含みません。通貨が USD（既定値）のままなら、この通信は発生しません。
- **アプリの更新確認（自動）**：アプリ内アップデートを提案するため、`UpdateChecker` が起動時と以後 24 時間ごとに、GitHub の公開 Releases API（`api.github.com`）へ Tokfuel の最新リリースを問い合わせます。リクエストに利用データや識別子は含みません。リリースファイル自体のダウンロードは、ポップオーバーの**アップデート**ボタンを押したときにのみ行います。
- **Cursor の価格表（自動、Cursor 導入時）**：Cursor のコスト見積りを精緻化するため、`CursorPricingService` が `cursor.com/docs/models-and-pricing` から公開価格表を 1 日 1 回取得します。ページ取得のみで、利用データは送信しません。
- **Cursor のダッシュボード利用量（Cursor 導入かつサインイン時）**：`CursorDashboardService` が、Cursor 自身のローカル `state.vscdb` にすでに保存されているセッショントークンを使い、Cursor のダッシュボード利用量 API（`api2.cursor.sh`）を呼び出します。送信するのはその認証ヘッダーと日付範囲のみで、プロンプトやローカル transcript は含みません。失敗時はローカルの SQLite トークンスナップショットにフォールバックします。
- **クラッシュレポート（配布ビルド、同意不要）**：GitHub Release など配布用にビルドしたアプリでは、Firebase Crashlytics へクラッシュ時のスタックトレースと端末・OS・アプリバージョンなどの診断情報を送ります。プロンプト、コスト、ファイルパス、transcript は含みません。開発用ビルド（`Scripts/build.sh` や `swift build`）では Firebase を起動せず、この通信は発生しません。
- **利用状況アナリティクス（配布ビルド、オプトイン）**：設定の「利用状況の送信を許可」を ON にしたときだけ、Firebase Analytics へ匿名のアプリ操作イベント（起動、タブ表示、設定キー名の変更など）を送ります。既定値は OFF です。プロンプト、コスト、パス、Skill / MCP 名など Claude / Cursor 由来のデータは送りません。OFF のときは Analytics の収集を無効化し、開発用ビルドでは同意の有無に関わらず送りません。

一般の Web リクエストと同様、これらの API の運営者は IP アドレスなどの標準的な接続メタデータを技術的に受け取ります。

## Tokfuel がしないこと

- アカウント作成やサインインを求めません。
- 広告やトラッキング（広告 ID の利用）を行いません。
- プロンプト、transcript、コスト金額、トークン数、プロジェクトパスを Firebase やその他の外部へ送りません。
- 開発用ビルドから Crashlytics / Analytics を送りません。

## このポリシーの変更

このポリシーは [Tokfuel リポジトリ](https://github.com/Tokfuel/Tokfuel)で管理し、変更はすべて git 履歴で確認できます。収集内容が変わる場合は、その変更を導入するリリースと同時にこのポリシーを改訂します。

## 連絡先

質問や懸念は <akidon0000@gmail.com> まで、または <https://github.com/Tokfuel/Tokfuel/issues> に Issue を立ててください。
