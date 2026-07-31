# AGENTS.md（AI セッションの作業合意）

> 人間かエージェントかを問わず、すべてのセッションが最初に読む共有前提。
> 人間のコントリビューター向けの入口は [`CONTRIBUTING.md`](CONTRIBUTING.md)。機能計画は
> [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues)（TF-NNNN 項目）で管理している。

## これは何か

**Tokfuel** は、Claude Code、Codex CLI、Cursor のコスト、プロンプト数、予算アラート、
設定可能なメニューバーゲージを可視化する SwiftUI ネイティブの macOS メニューバーアプリ。
フックも手動のトークン登録も要らず、これらのアプリがローカルに残しているデータを読むだけでよい。
同じ Mac に Codex CLI（`~/.codex/sessions/`）や Cursor があれば、そのコストも推定する。ただし
各ソースは独立に扱い、ラベルなしで Claude の合計に混ぜない。ソースコードはすべて
[`Tokfuel/Sources/`](Tokfuel/Sources/) にある。ファイル構成は README の
[Architecture](README.md#-architecture) 節を参照。

## グラウンドルール（違反禁止）

1. **ローカルオンリー**：収集したデータを Mac の外に出さない。テレメトリも送信もしない。
   例外はオーナー承認済みの次の 4 つだけ。
   1. ユーザーが JPY 表示を有効にしたときは、`ExchangeRateService` が Frankfurter API から
      USD→JPY レートを 1 日 1 回取得する（リクエストに使用状況データは載らない）。
   2. Mac に Cursor を検出したときは、`CursorPricingService` が Cursor 自身が公開している
      価格表（`cursor.com/docs/models-and-pricing`）を 1 日 1 回取得して Cursor のコスト推定を
      補正する。使用状況データは送らず、単なるページ取得にとどまる。`CursorPricing` は
      ハードコードした価格を持たず、価格を引けないモデル（未取得か、表に見つからない場合）は
      当て推量のレートではなく $0 として計上する。
   3. Cursor がインストール済みでサインインもされているときは、`CursorDashboardService` が
      Cursor のダッシュボード使用量 API（`api2.cursor.sh`）を呼ぶ。認証には Cursor がローカルの
      `state.vscdb` に保存済みのセッショントークンをそのまま使う。リクエストに載るのはこの
      認証ヘッダと日付範囲だけで、プロンプトやローカルのトランスクリプトは送らない。失敗した
      場合はローカル SQLite のトークンスナップショットへフォールバックする（Cursor 3.x では
      空のことが多い）。
   4. `UpdateChecker` が公開の GitHub Releases API
      （`api.github.com/repos/Tokfuel/Tokfuel/releases/latest`）を起動時に 1 回、以後 24 時間
      ごとにポーリングして新しいバージョンを検知する。リリースアセットのダウンロードは、
      ユーザーがポップオーバーのフッターで「アップデート」ボタンを押したときだけ GitHub から
      行う。これらのリクエストに使用状況データ、トランスクリプト、識別子は載らない。
2. **ゼロセットアップの維持**：アプリは Claude Code のトランスクリプトを直接読む。機能を
   動かすために、フック、外部ツールのインストール、Claude Code 側の設定を要求しない。
3. **retok は無改変で同梱**：`Sources/Resources/retok.py` と `locales/` は
   © Daiki Matsudate（MIT）。この場で編集せず、変更したい場合は上流へ PR を送る。
   `LICENSE-retok` とアプリ内のクレジット表記は維持する。出所と更新手順は
   [`README-retok.md`](Tokfuel/Sources/Resources/README-retok.md) にある。
4. **python3 は任意の依存**：無い環境では Claude のコスト分析がエラーを表示する。設定、
   プロンプト数、Cursor のフォールバックデータ、メニューバーアプリ本体は動き続けること。
5. **新規パッケージ依存の禁止**：Swift 6 / SwiftUI / macOS 14+、標準 SDK のみ。依存ゼロが
   「誰でもすぐビルドできる」を支えている。

## 検証ゲート

```bash
swift test               # ユニットテスト（Tokfuel/Tests、Swift Testing）
swift build -c release   # scripts/build.sh がパッケージする構成
```

CI（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)）が、すべての PR でテストと
リリースビルドを実行する。実行時に見える変更は、実アプリをインストールして観察する。
`bash scripts/build.sh` が `Tokfuel.app` を `/Applications` に配置して起動する（未検証の動作を
動くと主張せず、組み込みの `verify` スキルで確かめる）。ヘッドレスで検証できるロジック
（`BudgetMonitor` や `RetokReport` のデコードなど）は `Tokfuel/Tests` にあり、新しいロジックには
そこへテストを足す。実ユーザーの状態（`~/Library/Application Support/Tokfuel`）に触れるテストは
書かない。

`PopoverView`、`SettingsView`、`AboutView` の UI を追加または変更するときは、
`ScreenshotRenderer.allScreens()` のフィクスチャ画面（と
[`ui-preview.yml`](.github/workflows/ui-preview.yml) の `ORDER` / `screen_title` リスト）も
追加または更新して、`ui-preview 📸` ラベルが新しい状態を実際に描画できるようにする。ライブな
シングルトン経由でしか到達できないビュー（ネットワーク応答や実際のインストールパスに依存する
もの）には、`AppSettings.shared` が `prepareDefaults()` からフィクスチャ値を受け取るのと
同じ形で、注入可能なフィクスチャを用意する（`UpdateChecker.preview` を参照）。これを怠ると
新しい UI はレビュアーに見えないままになる（ポップオーバーのアップデートボタンが、TF-0029 の
フォローアップまで実際にそうだった）。

## ロードマップの回し方

機能は [Tokfuel/Tokfuel](https://github.com/Tokfuel/Tokfuel/issues) の GitHub Issue として
管理する。新機能は **Proposal**、バグは **Bug report** のテンプレートを使う。ロードマップは
[GitHub Project #1](https://github.com/orgs/Tokfuel/projects/1) からも見える。

このサイクルは [`.agents/skills/`](.agents/skills/) 配下のスキルが回す
（`.claude/skills` は Claude Code 互換のための symlink）。

- **`ideation`**：アイデアを GitHub Issue に仕立てる（起案のみ）。
- **`implementation`**：Issue 番号を起点に実装して出荷する（Issue 本文が仕様）。
- **`task-select`**：オープンな Issue を見渡し、次に実装する項目を選ぶ。

## 作業言語

このリポジトリの基本言語は日本語。

- セッションでのやり取り、GitHub Issue（タイトルと本文）、PR（タイトルと本文）、レビュー
  コメント、AGENTS.md やスキルといった作業文書は日本語で書く。文章は
  [`japanese-tech-writing`](.agents/skills/japanese-tech-writing/SKILL.md) スキルの規範に従う
  （Issue と PR の本文は敬体、作業規範の文書は常体）。
- コミットメッセージも日本語で書く（形式は「規約」のとおり）。
- README と SECURITY は例外として日英併記を続ける。ユーザーに見える変更では `README.md` と
  `README.ja.md` の両方を更新する。
- コード内のコメントは、周囲の既存コード（英語）に合わせる。
- 英語のまま残っている古い Issue や文書は、内容に手を入れる機会に日本語へ寄せれば足りる。
  翻訳だけを目的にした一括の書き換えはしない。

## 規約

- ブランチは 1 トピックにつき 1 本（`claude/<short-topic>`）。PR は小さく焦点を絞る。
- コミットの subject は 72 文字未満で変更を言い切り、body には理由（why）を書く。
  `feat(<scope>):` のような type プレフィックスは従来どおり使う。ロードマップの Issue を
  実装する PR は、タイトル先頭に `[TF-NNNN]` を付ける。
- UI の状態は `@MainActor` に置く。`UsageStore` を唯一の情報源に保ち、`PopoverView` は
  純粋な表示層のまま。設定は `AppSettings`（UserDefaults ベース）に置く。
