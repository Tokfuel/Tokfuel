<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>Claude Code の「コスト」をメニューバーから一目で。</strong><br/>
  Claude Code が <code>~/.claude/projects/</code> に書き出すトランスクリプトを読み、今日・期間のコストを表示する軽量な SwiftUI メニューバーアプリ（⛽️）です。セットアップ不要・テレメトリ無し — すべて Mac の中で完結します。
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml/badge.svg"/></a>
  <a href="https://github.com/akidon0000/tokfuel/releases"><img alt="Release" src="https://img.shields.io/github/v/release/akidon0000/tokfuel?style=flat-square"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.svg" alt="ポップオーバーのスクリーンショット" width="560"/>
</p>

## 特長

- 💵 今日・期間のコスト、日次コストグラフ、モデル別内訳、高コストセッション、retok の節約ヒント
- 🚨 **月と 1 日の予算上限**を独立に設定 — 上限が近づくと ⛽️ アイコンがオレンジ、超過で赤になり通知
- 📊 メニューバーには今日のコスト・今月のコスト・両方を表示可能（プレビュー付きで選択）
- 💱 表示通貨は USD / 日本円を選択可能（レートは [Frankfurter](https://frankfurter.dev) から 1 日 1 回取得）
- 🔒 ローカルファースト — テレメトリなし。唯一の通信は日本円選択時の為替レート取得だけです

## インストール

[Releases](https://github.com/akidon0000/tokfuel/releases) から `Tokfuel-x.y.z.zip` をダウンロードして展開し、`Tokfuel.app` を `/Applications` に入れるだけです。

アドホック署名のため初回起動は Gatekeeper にブロックされます。右クリック →**開く**、または**システム設定 → プライバシーとセキュリティ**で許可してください。

動作環境: macOS 14 以降。コスト分析に `python3`（Xcode Command Line Tools に同梱）を使います。

ソースからビルドする場合:

```bash
git clone https://github.com/akidon0000/tokfuel.git && cd tokfuel && ./build.sh
```

## コントリビュート

PR 歓迎です — [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。テストは `swift test`。ロードマップは [`roadmaps/`](roadmaps/README-ja.md) にあります。

## 謝辞

コスト分析には **[retok](https://github.com/d-date/retok)** を無改変で同梱しています — © [Daiki Matsudate (@d-date)](https://github.com/d-date)、[MIT License](Tokfuel/Sources/Resources/LICENSE-retok)。出所と更新手順は [README-retok.md](Tokfuel/Sources/Resources/README-retok.md) に記録しています。

## ライセンス

[MIT](LICENSE) © akidon0000 — ただし同梱の retok は上記の通り。
