# Tokfuel プライバシーポリシー

*最終更新: 2026-07-30*

このポリシーは、macOS アプリ Tokfuel がどのデータを読み取り、保存し、送信するかを説明します。Tokfuel の利用者と App Store 審査に向けた文書です。

## 要約

Tokfuel は個人データを収集せず、プロンプトやローカルの transcript を送信しません。Claude Code から読み取ったデータはすべて Mac の中にとどまります。アカウント、トラッキング、アナリティクス、サードパーティ SDK はいずれもありません。為替レートの取得や、Cursor を利用している場合は Cursor 自身の価格表とダッシュボード利用量の取得など、限定的で開示済みの通信のみ行います。

## アプリがローカルで読み取るデータ

Claude Code の利用状況を可視化するため、Tokfuel は Claude Code がすでに Mac 上に書き出しているファイルを読み取ります。

- **transcript**（`~/.claude/projects/` 以下）：Claude Code のコスト、プロンプト数、セッション数の算出に端末上で使います。
- **Cursor のローカルトークンデータベース**（`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`、Cursor 導入時のみ）：Cursor のコスト見積りに使います。このファイルは端末上でのみ読み取ります。認証トークンと日付範囲が外部に送信されるケースは下記のみです。
- **Codex CLI のセッションログ**（`~/.codex/sessions/` 以下、存在する場合）：同梱の retok スクリプト経由で端末上でのみ読み取り、セッション数・トークン数に加えて Codex のコストを見積ります。Claude の合計には合算せず、別建ての見積りとして扱います。

処理はすべて端末上で行います。集計結果や設定、通知の状態といった派生データは `~/Library/Application Support/Tokfuel/` とアプリのユーザーデフォルトにのみ保存し、送信しません。

現時点で Tokfuel が読み取るのは Claude Code、Cursor、Codex のローカルファイルです。将来のバージョンで他の AI コーディングツールへの対応を追加する場合も、同様にそれらのローカルファイルを端末上でのみ処理し、対応時にはこのポリシーを更新して対象ツールを明記します。

## 通信

Tokfuel が通信するのは以下のケースのみで、Claude Code の transcript やプロンプトを送信することはありません。

- **為替レート（オプトイン）**：表示通貨を日本円に切り替えると、[Frankfurter API](https://frankfurter.dev)（`api.frankfurter.dev`）から USD→JPY の為替レートを 1 日 1 回まで取得します。利用データ、識別子、Mac 上のコンテンツは一切含みません。通貨が USD（既定値）のままなら、この通信は発生しません。
- **Cursor の価格表（自動、Cursor 導入時）**：Cursor のコスト見積りを精緻化するため、`CursorPricingService` が `cursor.com/docs/models-and-pricing` から公開価格表を 1 日 1 回取得します。ページ取得のみで、利用データは送信しません。
- **Cursor のダッシュボード利用量（Cursor 導入かつサインイン時）**：`CursorDashboardService` が、Cursor 自身のローカル `state.vscdb` にすでに保存されているセッショントークンを使い、Cursor のダッシュボード利用量 API（`api2.cursor.sh`）を呼び出します。送信するのはその認証ヘッダーと日付範囲のみで、プロンプトやローカル transcript は含みません。失敗時はローカルの SQLite トークンスナップショットにフォールバックします。

一般の Web リクエストと同様、これらの API の運営者は IP アドレスなどの標準的な接続メタデータを技術的に受け取ります。Cursor が未導入であれば、発生しうるのは為替レートのリクエスト（かつ JPY をオプトインした場合のみ）だけです。

## Tokfuel がしないこと

- アカウント作成やサインインを求めません。
- テレメトリ、アナリティクス、クラッシュレポートを送信しません。
- 広告やトラッキングを行いません。
- サードパーティ SDK を含みません（同梱の [retok](https://github.com/d-date/retok) スクリプトはローカルで動作します）。

## このポリシーの変更

このポリシーは [Tokfuel リポジトリ](https://github.com/Tokfuel/Tokfuel)で管理し、変更はすべて git 履歴で確認できます。将来のバージョンが何らかのデータ収集（たとえばオプトインのアナリティクス）を行う場合は、その収集を導入するリリースと同時にこのポリシーを改訂します。

## 連絡先

質問や懸念は <akidon0000@gmail.com> まで、または <https://github.com/Tokfuel/Tokfuel/issues> に Issue を立ててください。
