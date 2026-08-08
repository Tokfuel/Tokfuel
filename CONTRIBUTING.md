# Contributing to Tokfuel

Thanks for your interest! This is a small, personal-use macOS menu-bar app, but PRs that make it better for everyone are very welcome. This guide is intentionally short — keep it in mind, but don't sweat the small stuff.

[English](#en) · [日本語](#ja)

---

<a id="en"></a>

## English

### Ground rules

- **Be kind.** This project follows the spirit of the [Contributor Covenant](https://www.contributor-covenant.org/). Be respectful in issues, PRs, and reviews.
- **One topic per PR.** Smaller, focused PRs get merged faster than sprawling ones.
- **Discuss before big changes.** For features that change UX or architecture, open an issue first so we can align before you spend time coding. Settled architecture decisions live in [ADR/](ADR/) (see [ADR/TEMPLATE.md](ADR/TEMPLATE.md)).

### Dev setup

```bash
git clone https://github.com/akidon0000/Tokfuel.git
cd Tokfuel

bash Scripts/setup.sh             # install local git hooks (.githooks)
swift build            # debug build
swift run -c release   # run the app from source
bash Scripts/build.sh             # package + install Tokfuel.app to /Applications
bash Scripts/screenshot.sh        # regenerate README + Site screenshots from the real UI
```

**Screenshots (README + download page).** `bash Scripts/screenshot.sh` renders the real
`PopoverView` once and writes the same PNG to both `Assets/screenshot.png` (README) and
`Site/Assets/images/screenshot.png` (GitHub Pages). After a UI change, run it locally and
commit both files — don't leave the Site copy stale. Releases also open a review PR with a
fresh pair (see `.github/workflows/release.yml`); that path still wants a human look before
merge.

The app reads Claude Code transcripts under `~/.claude/projects/` directly (no hooks or extra setup) — if you use Claude Code at all, you already have data to exercise the UI. Claude cost analysis additionally needs `python3` (ships with the Xcode Command Line Tools) to run the bundled retok.

**Debug section.** To check the menu-bar readout, icon colors, and budget alerts at an arbitrary
amount instead of waiting for real usage, install a debug-configuration build:

```bash
bash Scripts/build.sh --debug   # debug build, with the Settings → デバッグ section
```

It lets you override today's / this month's cost or simulate "report not loaded". The whole
feature is wrapped in `#if DEBUG`, so it is never compiled into the release build users install.
Overrides are in-memory only — a relaunch always returns to real data.

**App icon.** The design is not edited here. It lives as an Icon Composer document in
[Tokfuel/icon](https://github.com/Tokfuel/icon); this repository only carries the exported
`Assets/icon-master.png` and the sizes derived from it. After a design change, export a
1024×1024 PNG from Icon Composer, replace the master, and rebake:

```bash
swift Assets/make-icon.swift   # rewrites Assets/AppIcon.iconset/ and Assets/AppIcon.icns
```

### Coding style

- SwiftUI + Swift Concurrency. UI-touching state lives on `@MainActor`.
- Keep `UsageStore` the single source of truth for parsing and aggregation; `PopoverView` stays pure presentation.
- Don't add dependencies unless there's a strong reason — staying dependency-free keeps the app trivial to build.
- Match the existing file layout under [`App/Tokfuel/`](App/Tokfuel/).

### Commit messages

- Subject line: imperative, < 72 chars. e.g. `Add launch-at-login toggle`.
- Body (optional): the *why*, not the *what*. The diff already shows the what.

### PR checklist

- [ ] Builds cleanly: `swift build -c release`
- [ ] Runs and behaves as expected on macOS 14+
- [ ] UI changes include a screenshot or short GIF (maintainers can also add the `ui-preview 📸` label to a same-repo PR to have a bot render the popover — default and, with the footer's Update button showing, the update variant — settings — default/advanced/debug — and about screens — see `.github/workflows/ui-preview.yml`)
- [ ] README / README.ja.md updated if user-visible behavior changed
- [ ] No new dependencies (or, if so, explained in the PR description)

Opening a PR out of draft automatically requests review from the `@Tokfuel/core-maintainers` team
(see `.github/workflows/auto-request-review.yml`); draft PRs are skipped until marked ready.

### Roadmap

Planned and shipped features are tracked as [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues)
(TF-NNNN items). Use the **Proposal** template for new features and the **Bug report** template for
bugs. The same backlog is also visible on
[GitHub Project #1](https://github.com/orgs/Tokfuel/projects/1). A PR that implements a numbered
issue prefixes the PR title `[TF-NNNN]`.

### Good first issues

Open [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues) and
[Project #1](https://github.com/orgs/Tokfuel/projects/1) are the up-to-date backlog. Pick a small,
self-contained Proposal if you're looking for something to build.

---

<a id="ja"></a>

## 日本語

### 心構え

- **やさしく。** [Contributor Covenant](https://www.contributor-covenant.org/) の精神に沿って、Issue / PR / レビューで敬意を持って接してください。
- **1 PR 1 トピック。** 小さく焦点が絞られた PR の方が早くマージできます。
- **大きな変更は先に相談。** UX やアーキテクチャを変えるような機能は、コードを書く前に Issue を立てて方向性を合わせましょう。決まった方針は [ADR/](ADR/) に残します（型は [ADR/TEMPLATE.md](ADR/TEMPLATE.md)）。

### 開発環境のセットアップ

```bash
git clone https://github.com/akidon0000/Tokfuel.git
cd Tokfuel

bash Scripts/setup.sh             # ローカルの git hooks（.githooks）を取り込む
swift build            # デバッグビルド
swift run -c release   # ソースから実行
bash Scripts/build.sh             # Tokfuel.app をパッケージして /Applications にインストール
bash Scripts/screenshot.sh        # README + Site のスクリーンショットを実物の UI から再生成
```

**スクリーンショット（README + ダウンロードページ）。** `bash Scripts/screenshot.sh` は実物の
`PopoverView` を 1 回描画し、同じ PNG を `Assets/screenshot.png`（README）と
`Site/Assets/images/screenshot.png`（GitHub Pages）の両方へ書き出します。UI を変えたら
手元で実行して両ファイルをコミットしてください。Site 側だけ古いまま残さないこと。
リリース時も同じペアを撮り直した確認用 PR が立ちます（`.github/workflows/release.yml`）。
マージ前に目視してください。

アプリは `~/.claude/projects/` 配下の Claude Code トランスクリプトを直接読みます（フックや追加設定は不要）。Claude Code を使っていれば、UI を確認するデータはすでに手元にあります。Claude のコスト分析だけは同梱 retok の実行に `python3`（Xcode Command Line Tools に同梱）が必要です。

**デバッグセクション。** メニューバーの表示・アイコン色・予算アラートを、実際の使用量を待たずに任意の金額で確認できます。debug 構成のビルドを入れてください。

```bash
bash Scripts/build.sh --debug   # 設定に「デバッグ」セクションが付く debug ビルド
```

設定の一番下で、今日／今月のコストを上書きしたり「レポート未取得」を再現できます。この機能全体を `#if DEBUG` で囲んでいるため、ユーザーが入れるリリースビルドにはコンパイルされません。上書き値はメモリ上だけに持つため、再起動すれば必ず実データに戻ります。

**アプリアイコン。** デザインはこのリポジトリでは編集しません。正本は [Tokfuel/icon](https://github.com/Tokfuel/icon) の Icon Composer ドキュメントで、ここが持つのは書き出した `Assets/icon-master.png` とそこから焼いた各サイズだけです。デザインを変えたら、Icon Composer から 1024×1024 の PNG を書き出してマスターを差し替え、焼き直してください。

```bash
swift Assets/make-icon.swift   # Assets/AppIcon.iconset/ と Assets/AppIcon.icns を再生成
```

### コーディングスタイル

- SwiftUI + Swift Concurrency。UI に触る状態は `@MainActor` に置く。
- パースと集計は `UsageStore` に集約（SSOT）。`PopoverView` は純粋な表示層に保つ。
- 依存パッケージは原則追加しない（ビルドを最小に保ちたい）。
- ファイル配置は既存の [`App/Tokfuel/`](App/Tokfuel/) に揃える。

### コミットメッセージ

- Subject: 命令形・72 文字未満。例: `Add launch-at-login toggle`
- Body（任意）: *何をしたか* ではなく *なぜそうしたか* を書く。差分を見れば「何」は分かるので。

### PR チェックリスト

- [ ] ビルドが通る: `swift build -c release`
- [ ] macOS 14+ で意図どおりに動く
- [ ] UI 変更はスクリーンショットか短い GIF を添付（同一リポジトリの PR なら `ui-preview 📸` ラベルを付けて、ポップオーバー（既定・フッターにアップデートボタンが出た状態）・設定（既定/詳細展開/デバッグ展開）・About をまとめてボットに撮らせてもよい。fork からの PR では GitHub の権限制約で動かない — `.github/workflows/ui-preview.yml` 参照）
- [ ] ユーザーから見える変更があれば README / README.ja.md も更新
- [ ] 新規依存は追加しない（追加する場合は PR 本文で理由を説明）

PR を Draft から Ready for review にすると、`@Tokfuel/core-maintainers` チームへ自動でレビューが
リクエストされます（`.github/workflows/auto-request-review.yml` 参照）。Draft のままの PR には
何も起きません。

### ロードマップ

計画中・実装済みの機能は [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues)（TF-NNNN 項目）
として管理しています。新機能は **Proposal**、バグは **Bug report** のテンプレートを使ってください。
同じバックログは [GitHub Project #1](https://github.com/orgs/Tokfuel/projects/1) からも見えます。
番号付きの Issue を実装する PR は、タイトル先頭に `[TF-NNNN]` を付けます。

### 最初の一歩におすすめ

オープンな [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues) と
[Project #1](https://github.com/orgs/Tokfuel/projects/1) が最新のバックログです。
作るものを探すなら、小さく完結しやすい Proposal を選んでください。
