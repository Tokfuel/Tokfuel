<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>AI コーディングのコストをメニューバーから一目で。</strong>
</p>

<p align="center">
  macOS 向けの軽量な SwiftUI メニューバーアプリ（⛽️）です。<br/>
  Claude Code が <code>~/.claude/projects/</code> に書き出すトランスクリプトを読み、<br/>
  今日・期間のコストを表示します。セットアップ不要 — すべて Mac の中で完結します。
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/Tokfuel/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/Tokfuel/actions/workflows/ci.yml/badge.svg"/></a>
  <a href="https://github.com/akidon0000/Tokfuel/releases"><img alt="Release" src="https://img.shields.io/github/v/release/akidon0000/Tokfuel?style=flat-square"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.png" alt="ポップオーバーのスクリーンショット" width="560"/>
</p>

## 特長

- 💵 **コストが一目で**

  今日・期間のコスト、日次グラフ、モデル別内訳、高コストセッション、retok の節約ヒント。

- 🚨 **予算**

  月と 1 日の上限を独立に設定。
  上限が近づくと ⛽️ アイコンがオレンジ、超過で赤になり通知します。

- 📊 **メニューバー表示**

  見る指標（今日、今月、両方、プロンプト数）と見せ方（金額、パーセント、リング、
  リング + パーセント、アイコンのみ）を組み合わせて選べます。「予算までの残り」も選択できます。
  パーセントとゲージの分母は、予算上限か過去 30 日の日次平均です。
  ゲージの形はリング（⛽️ アイコンと並べる／置き換える）か、⛽️ アイコン自身が下から
  塗り上がるタンクから選べます。予算内は青、しきい値でオレンジ、超過で赤になり、
  今日と今月は別々に色が変わります。設定にプレビュー付き。

- 💱 **ドル / 日本円**

  予算入力を含む全金額の通貨を切り替え。
  レートは [Frankfurter](https://frankfurter.dev) から 1 日 1 回取得します。

- 🔒 **ローカルファースト**

  テレメトリなし。唯一の通信は為替レート取得（オプトイン）だけです。

## インストール

1. [Releases](https://github.com/akidon0000/Tokfuel/releases) から `Tokfuel-x.y.z.zip` をダウンロード。
2. 展開して `Tokfuel.app` を `/Applications` へドラッグ。
3. 初回起動はアプリを右クリック →**開く**
   （または**システム設定 → プライバシーとセキュリティ**で許可）。

> [!NOTE]
> 警告が出るのはアドホック署名のためです。
> ブラウザではなく `curl` でダウンロードすると警告自体が出ません。

**動作環境**

- macOS 14 以降
- コスト分析に `python3`（Xcode Command Line Tools に同梱）

**ソースからビルド**

```bash
git clone https://github.com/akidon0000/Tokfuel.git
cd Tokfuel
bash scripts/build.sh
```

## コントリビュート

PR 歓迎です — [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

- テスト: `swift test`
- ロードマップ: [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues)
- 脆弱性を見つけたときは非公開で報告してください。[SECURITY.ja.md](SECURITY.ja.md) を参照。

### コントリビューター

<!-- contributors:start -->
<!-- contributors:end -->

## 謝辞

- **コスト分析** — [retok](https://github.com/d-date/retok) を無改変で同梱。
  © [Daiki Matsudate (@d-date)](https://github.com/d-date)、[MIT License](Tokfuel/Sources/Resources/LICENSE-retok)。
- **アプリアイコン** — [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) でデザイン。
  ソースドキュメントは [Tokfuel/icon](https://github.com/Tokfuel/icon) にあります。
- **為替レート** — [Frankfurter](https://frankfurter.dev)。
- **ロードマップ規約** — [bajutsu](https://github.com/bajutsu-e2e/bajutsu) の Issue 駆動開発ワークフローを参考に設計。

## ライセンス

[MIT](LICENSE) © [Dan Akiyama (@akidon0000)](https://github.com/akidon0000)
