---
name: implementation
description: >-
  Tokfuel の GitHub Issue を番号から最後まで実装するスキル。「/implementation #5」
  「#5 を実装して」「implement #5」のように実装する Issue を名指しされたとき、または
  タイトルの断片などで既存の提案をコードにするよう求められたときに使う。Issue 本文を仕様として
  扱い、グラウンドルールに沿って計画を立て、確認を取ってから書き、ビルドとテストで実装し、
  差分をレビューして磨き、Issue を閉じ、`swift build` が緑であることを示す。ideation スキルの
  対になる実装側。
---

# GitHub Issue の実装

Tokfuel の GitHub Issue を 1 件、提案の状態から出荷済みの緑のコードまで運ぶ。判定は常に
`swift build`（と組み込みのレビュー系スキル）であって、LLM の心証ではない。仕様は Issue 本文の
「詳細設計」セクション（古い Issue では `Detailed design`）。会話は日本語を基本とし、コード、
コミット、PR の文章は下の規約に従って書く。

## プロジェクトのグラウンドルール（すべての行の枠）

1. **ローカルオンリー**：Claude / Cursor / Codex 由来のデータを外に出さない。追加の通信は
   AGENTS.md のオーナー承認済み例外に限る（配布ビルドの Crashlytics、オプトイン Analytics を含む）。
2. **ゼロセットアップの維持**：ユーザーに Claude Code の設定やフックの導入を求めない。
3. **retok は無改変で同梱**：同梱の retok をこの場で編集しない。ライセンスとクレジットを維持する。
4. **python3 は任意**：python3 が無くても Claude のコスト分析が緩やかに縮退する状態を保つ。
5. **Swift 6 / SwiftUI / macOS 14+**：`swift build` は常に緑を保つ。新規パッケージは原則禁止で、
   例外は `firebase-ios-sdk`（Analytics / Crashlytics のみ）に限る。

## 進め方

### 1. Issue を特定する

Issue 番号（`#5`、`5`）でもタイトルの断片でも受け付ける。まず全文を取得する。

```bash
gh issue view <number> --repo Tokfuel/Tokfuel --json number,title,body,labels 2>/dev/null
```

**何よりも先に、その Issue をユーザーに説明する**。番号とタイトル、何をなぜ提案しているのかの
平易な要約、現在の状態を伝える。すでにクローズ済みなら手を止め、本当は何をしたいのかを確認する。

### 2. 仕様とコードで足場を作る

- Issue の「詳細設計」と、そこに書かれた代替案や制約を読む。
- Issue が参照するファイルはすべて開き、周辺コードまで読む。変更を既存の形に馴染ませるため。
  大きな項目では、読む作業を `Explore` エージェントに広げ、方針は `Plan` エージェントで練る。
- 依存関係を確かめる。設計が別のオープン Issue をブロッカーとして参照しているなら、それを
  表に出し、どう進めるかを確認する。

### 3. 焦点の絞れたブランチを用意する

ブランチは 1 トピックにつき 1 本。`main` 上にいるなら最新の origin から切る:
`git fetch origin && git switch -c claude/<slug> origin/main`。触るのはこの Issue に必要な
ファイルだけ。設計上どうしても横断的な変更になるなら、先にそう宣言する。

### 4. 計画を立て、書く前に確認を取る

Issue 1 件の実装は大きく、巻き戻しにくい。だから具体的な計画にユーザーの同意を得てから書く
（`EnterPlanMode` の利用を検討する）。計画には次を含める。追加または変更するファイルと変更の
形、動くことを証明する観測可能な結果（テスト、または実アプリで確かめる挙動）、追加するテスト、
動かすべきドキュメント（日英両方）、グラウンドルールと擦れる点があるならその設計の直し方。

### 5. 実装する

- **周囲のスタイルに合わせる**：コメントは what ではなく why を、周囲と同じ密度で書く。
- **グラウンドルールをコードで守る**：ローカルオンリー、python3 不在時の縮退、retok 無改変。
- **テストが回帰の網**：アプリ全体を起動せずに検証できる新ロジックにはテストを付ける。
- **ドキュメントは日英併記**：文書化済みの挙動を変えたら `README.md` と `README.ja.md` の
  両方を更新する。日本語は [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) に従う。
- **UI を足したら ui-preview も同じ PR で更新する（必須）**：`PopoverView` /
  `SettingsView` / `AboutView`、または単独で見せる新規 View（同意ダイアログやアラートなど）を
  追加・変更したときは、次を同じ差分に含める。怠るとレビュアーに新しい UI が見えない。
  1. [`ScreenshotRenderer.allScreens()`](../../../Tokfuel/Sources/ScreenshotRenderer.swift)
     にフィクスチャ画面を追加または更新する
  2. [`.github/workflows/ui-preview.yml`](../../../.github/workflows/ui-preview.yml) の
     `ORDER` と `screen_title` を揃える
  3. ライブなシングルトン経由でしか到達できない状態は、`UpdateChecker.preview` や
     `AppSettings` の `prepareDefaults()` と同じ形で注入可能なフィクスチャを用意する
  4. ダイアログやパネルの文面は SwiftUI の表示 View に置き、ランタイムとプレビューで
     同じ View を使う（`AnalyticsConsentView` の流儀）

### 6. 差分をレビューして磨く

`swift build` が証明するのはコンパイルが通ることだけで、設計やロジックの良し悪しは判定しない。
その隙間を、毎回、差分に対して埋める。

- 組み込みの **`simplify`** スキル（再利用、死んだコード、過剰な抽象化）を実行し、修正を適用する。
- 組み込みの **`code-review`** スキルで、ビルドには見えない正しさのバグを探す。
- 正しさが実行時の挙動に懸かる項目なら、組み込みの **`verify`** スキルで実アプリを動かす。
  `bash scripts/build.sh` でビルドとインストールをし、挙動を実際に操作して、見たものを報告する。
  動作未確認のまま動くと主張しない。

### 7. 検証する

```bash
swift build                    # 緑が必須
swift build -c release         # scripts/build.sh が使うリリース構成
```

ビルドを赤のまま残さない。実行時に見える変更なら、さらに `bash scripts/build.sh` で実アプリを
確認する（`verify` を使う）。

### 8. PR は求められたときだけ

自分のブランチへ push する。ユーザーに求められない限り PR は開かない。PR のタイトルと本文は
[PR テンプレート](../../../.github/PULL_REQUEST_TEMPLATE.md)に従う（タイトルは
`[TF-NNNN] 日本語 / English`、本文は背景 / 変化 / 判断 / 懸念）。コミットは
`feat(<scope>):` や `fix(<scope>):` の形式で、要約を日本語で書く。PR 本文に `Closes #<number>` を
入れて、マージで Issue が自動クローズされるようにする。ラベルは種類に応じて付与する。

## 参照

- [`ideation`](../ideation/SKILL.md)：ここで実装する提案を起案する側。
- 組み込みの **`simplify`** / **`code-review`** / **`verify`** スキル：手順 6 と 7 で使う。
