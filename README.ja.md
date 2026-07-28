<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>Claude Code の「コスト」をメニューバーから一目で。</strong><br/>
  ローカルの Claude Code 利用ログを読み込み、今日・期間のコストを表示する、軽量な SwiftUI 製メニューバーアプリ（⛽️）です。
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <img alt="Language" src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white"/>
  <img alt="UI" src="https://img.shields.io/badge/SwiftUI-NSStatusItem-D97757?style=flat-square"/>
  <img alt="License" src="https://img.shields.io/badge/License-MIT-2E2018?style=flat-square"/>
  <img alt="PRs" src="https://img.shields.io/badge/PRs-welcome-E8927C?style=flat-square"/>
  <a href="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml/badge.svg"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.svg" alt="ポップオーバーのスクリーンショット" width="560"/>
</p>

## ✨ なぜ作ったか

Claude Code は普段から多くの利用シグナルを蓄積しています。中でも重要なのは「各セッションにいくらかかったか」ですが、そのデータは `~/.claude/projects/` 配下のトランスクリプトに溜まったままです。**Tokfuel** は**セットアップ不要**でコストを可視化します。アプリを入れるだけでトランスクリプトを直接読み込みます。フックも CLI のインストールもサーバーもテレメトリも無し — すべて Mac の中で完結します。現行リリースは意図的に絞った**コスト表示専用の MVP** で、メニューバーの燃料ポンプアイコンが「今日どれだけ燃料を使ったか」を示します。

コスト分析には、[Daiki Matsudate (@d-date)](https://github.com/d-date) さん作の Claude Code ログのトークン効率アナライザ **[retok](https://github.com/d-date/retok)** を同梱して利用しています（MIT License。詳細は[謝辞](#-謝辞--サードパーティライセンス)を参照）。

## 🚀 特長

- 💵 **コスト表示（retok 連携）** — 今日/期間のコスト、キャッシュヒット率、プロンプト単価、日次コストグラフ、モデル別内訳、高コストセッション、そして retok の改善提案（キャッシュ TTL 切れ・巨大コンテキスト・リトライループなど）。
- ⛽️ **燃料ポンプのメニューバーアイコン** — `fuelpump.fill` アイコンの横に今日の推定コストを常時表示し、予算の状態に応じて色が変わります。
- ⚙️ **セットアップ不要** — `~/.claude/projects/` のトランスクリプトを直接走査（増分キャッシュ付き）し、ログイン項目にも自動登録。入れるだけで動きます。
- 🛠️ **設定** — ログイン時起動、メニューバー表示（今日のコスト / 今月のコスト / 両方 / プロンプト数 / アイコンのみ。実データのプレビュー付き）、既定の集計期間、レポート言語、そして **Claude ディレクトリ**の場所。標準以外の構成でも動きます。
- 🚨 **予算アラート** — **月**（「過去 30 日（ローリング）」か「今月（1 日から）」を選択）と **1 日**の上限金額 (USD) を独立に設定できます。しきい値（70/80/90%）に達するとメニューバーのアイコンがオレンジになり通知、どちらかの上限超過で赤になります。ポップオーバーには上限ごとにしきい値目盛り付きの予算バーを表示。
- 📊 **メニューバー常駐** — 今日の推定コストをメニューバーに常時表示。Dock を汚さず（`LSUIElement = YES`）、10 分ごとに自動更新。
- 🪞 **自己計測** — Tokfuel は*自分自身の* UI イベント（ポップオーバーを開いた、設定を変えた。トランスクリプトの内容・プロジェクト名・コストは決して含みません）を `~/Library/Application Support/Tokfuel/events/` のローカル JSONL に記録し、今後の改善判断の根拠にします。Mac の外に出ないためデフォルト有効で、設定から表示・無効化・全削除ができます。
- 🔒 **100% ローカル** — データは外に出ません。

## 🧰 動作環境

- macOS **14.0** Sonoma 以降
- Xcode **16+** / Swift **6.0** ツールチェイン（ビルド用）
- `python3`（Xcode Command Line Tools に同梱）— コスト分析の retok 実行に使用。無い場合はコストレポートの代わりにエラーを表示します

## 📦 インストール

### 方法 1: リリースをダウンロード（おすすめ）

[Releases ページ](https://github.com/akidon0000/tokfuel/releases)から `Tokfuel-x.y.z.zip` をダウンロードして展開し、`Tokfuel.app` を `/Applications` に入れるだけです。バイナリはユニバーサル（Apple Silicon / Intel 両対応）で、retok も同梱済み — 他に入れるものはありません。

アドホック署名（有料の Apple Developer ID なし）のため、初回起動は Gatekeeper にブロックされます。アプリを右クリックして**開く**を選ぶか、**システム設定 → プライバシーとセキュリティ → このまま開く**で許可してください。コマンドでも解除できます:

```bash
xattr -d com.apple.quarantine /Applications/Tokfuel.app
```

### 方法 2: スクリプトでビルド & インストール

```bash
git clone https://github.com/akidon0000/tokfuel.git
cd tokfuel

./build.sh
```

`build.sh` はリリースビルドを行い、`Tokfuel.app` を `/Applications` にパッケージし、アドホック署名して起動します。

### 方法 3: ソースから実行

```bash
swift run -c release
```

> [!NOTE]
> このアプリは**アドホック署名**（`codesign --sign -`）です。初回起動時に「開発元を確認できない」と警告が出ることがあります。アプリを右クリックして **開く** を選ぶか、**システム設定 → プライバシーとセキュリティ** から許可してください。

## 🖱 使い方

1. メニューバーには ⛽️ アイコンの横に常に**今日の推定コスト**が表示されます。クリックでポップオーバーを開きます。
2. ポップオーバーには期間合計（Today / 7d / 30d）・キャッシュヒット率・日次コストグラフ・モデル別コスト・retok の改善提案（タップで詳細）・高コストセッションを表示します。ヘッダー直下には今日のコスト・プロンプト数・セッション数の「Today」行が常時表示されます。
3. **↻** で再走査、**⚙** で設定、**⊗** で終了。放っておいても 10 分ごとに自動更新されます。

## 🗂 データソース

すべて Claude Code が普段から書き出しているトランスクリプトから導出します。フックや追加設定は不要です:

```
~/.claude/projects/
└── <project-dir>/
    └── <session>.jsonl   # tool_use（Skill / mcp__* / Agent）とプロンプトを走査
```

- Swift 製スキャナが Skill / MCP / サブエージェント呼び出しとプロンプト数をリポジトリ×日単位で集計。`~/Library/Application Support/Tokfuel/` にファイル単位の増分キャッシュを持つため再走査は高速です。
- 同梱の [retok](https://github.com/d-date/retok) が同じトランスクリプトからトークン使用量・コスト推定・キャッシュ効率・改善提案を算出します（`retok --json`）。
- **Claude ディレクトリ**（`~/.claude`）は設定で変更でき、標準以外の構成でも動きます。

## 🏗 アーキテクチャ

```
Tokfuel/Sources/
├── App.swift                # @main、AppDelegate、NSStatusItem + NSPopover、ログイン項目、自動更新
├── PopoverView.swift        # SwiftUI ポップオーバー: コスト表示専用の MVP ビュー
├── UsageStore.swift         # ObservableObject: スキャナと retok の結果を統合・集計
├── TranscriptScanner.swift  # ~/.claude/projects の JSONL を走査（増分キャッシュ付き）
├── RetokService.swift       # 同梱 retok を python3 で実行し JSON レポートをデコード
├── AppSettings.swift        # UserDefaults 永続化の設定（ログイン起動・表示・期間・言語）
├── SettingsView.swift       # SwiftUI の設定ウィンドウ
└── Resources/
    ├── retok.py             # d-date/retok の無改変同梱コピー（© Daiki Matsudate, MIT）
    ├── locales/             # retok の翻訳（改善提案がロケールに追従）
    ├── LICENSE-retok        # retok の MIT ライセンス全文（アプリに同梱される）
    └── README-retok.md      # 出所の記録: 上流リポジトリ・取り込みコミット・更新手順
```

- `UsageStore` が単一の信頼できる情報源（SSOT）。トランスクリプト走査と retok レポートを統合して publish します。
- `PopoverView` は純粋な表示層で、ストアに駆動されます。
- `AppDelegate` がステータスアイテムとポップオーバーのライフサイクルを保持。アクセサリ（Dock アイコン無し）として動作し、ログイン項目に自動登録します。

## 🤝 コントリビュート

PR 歓迎です！開発環境・コーディングスタイル・PR チェックリストは [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

計画中・実装済みの機能は [`roadmaps/`](roadmaps/README-ja.md) の **CU 項目**（二言語の
Swift-Evolution 形式提案。[bajutsu](https://github.com/bajutsu-e2e/bajutsu) の規約を参考にした
もの）として管理しています。そこの Proposals 表と「未整理のアイデア」が最新のバックログです。
初手の一例:

- 期間フィルタ（今日 / 今週 / 全期間）。
- 編集メトリクス（追加 / 削除行数）の可視化。データはすでにデコード済み。
- [CU-0002](roadmaps/CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) — コスト分析の Swift ネイティブ再実装（python3 依存の廃止）。

## 🙏 謝辞 / サードパーティライセンス

本アプリは **[retok](https://github.com/d-date/retok)** を同梱しています — © [Daiki Matsudate (@d-date)](https://github.com/d-date) さんの著作物で、[MIT License](Tokfuel/Sources/Resources/LICENSE-retok) の下で公開されています。同梱コピーは無改変（ファイル名のみ `retok` → `retok.py`）で、ライセンス全文をアプリバンドル内に同梱し、出所（取り込みコミット・更新手順）は [README-retok.md](Tokfuel/Sources/Resources/README-retok.md) に記録しています。本アプリのコスト推定・キャッシュ効率分析・改善提案はすべて retok の成果です。

## 📄 ライセンス

[MIT](LICENSE) © akidon0000 — ただし同梱の retok は上記の通り。
