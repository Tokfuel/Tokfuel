# E2E メニューバー

アプリ（`App/Tokfuel`）を、実際のメニューバー操作で通すテストの置き場です。

シナリオ設計の正本は [`../TestDocs`](../TestDocs/) です。ユニットは [`../UnitTests`](../UnitTests/)、結合は [`../IntegrationTests`](../IntegrationTests/) に置きます。

## 方針

- Maestro / Appium / 別リポジトリは持ち込まない
- 見た目の固定はこの通しテストではなく VRT（`ScreenshotRenderer` / `ui-preview`）に置く
- 操作は macOS のアクセシビリティ API で行う（実装詳細。チェック名には出さない）
- 詳細な優先順位は [`../TestDocs/README.md`](../TestDocs/README.md) の「担保手段」節

## コアシナリオ（6 本）

まずは次の 6 本を `App/Tests/E2E/run-core6.sh` がまとめて回します。CI 上の表示名は **E2E メニューバー** です。

- `MenuBar-01-open-home`
- `Cost-01-chart-style`
- `Cost-02-period-switch`
- `Cost-03-model-list`
- `Settings-01-open`
- `Settings-02-reflect`

```bash
bash App/Tests/E2E/run-core6.sh
```

デバッグビルドの Tokfuel を `--e2e-fixture` で起動し、`TokfuelE2E` ドライバがメニューバーを操作します。実ユーザーの `~/Library/Application Support/Tokfuel` は触りません。

`--e2e-fixture` では NSPopover が AX ツリーに載らないため、ステータス項目のクリックで同じホーム UI を `NSPanel` に出します（本番の見た目経路は従来どおり NSPopover）。

## 全シナリオ / ドメイン単位の実行

[`../TestDocs`](../TestDocs/) の全 132 本には、`TokfuelE2E` の `--suite` / `--only` で個別に実装済みです。
シナリオ実装は `Driver/Scenarios{Budget,Cost,Cursor,MenuBar,Settings}.swift`（`AXDriver` への
extension）に分かれ、`Driver/Registry.swift` が束ねて `--suite` / `--only` の絞り込みを行います。

```bash
# 132 本すべて
bash App/Tests/E2E/run-all.sh

# ドメイン単位（Budget / Cost / Cursor / MenuBar / Settings）
SUITE=Budget bash App/Tests/E2E/run-all.sh

# ドライバを直接使う場合（コアシナリオ 6 本と同じ起動済みプロセスに対して）
.build/debug/TokfuelE2E --pid <PID> --suite all
.build/debug/TokfuelE2E --pid <PID> --suite Cost
.build/debug/TokfuelE2E --pid <PID> --only Cost-12-jpy-formatting
```

`--suite` を省略すると既定は `core6`（`run-core6.sh` との後方互換）です。全ドメインの記録は
[`recordings/all.json`](recordings/all.json) に残ります（成功実行のたびに `.build/e2e/all-last.json`
へ実測を書き戻し、リポジトリ正本を更新するときだけ `TOKFUEL_E2E_UPDATE_REPO_RECORDING=1` を付けます）。

`--e2e-fixture`（プロファイル省略）1 プロセスだけで検証できないシナリオ（Cursor 劣化・サインイン、
予算「超過」、セッション一覧、初回同意ダイアログなど、別プロファイル起動が要る観点）は、各
シナリオの実装コメントに理由を書いたうえで、到達可能な範囲の健全性確認にフォールバックします。

### 成功記録と再実行の高速化

前回成功した挙動は [`recordings/core6.json`](recordings/core6.json) に残します（必要 identifier・起動待ち・timeout 係数）。

- 次回以降はこの記録を読んで待ち時間を短縮します
- 実行成功時は `.build/e2e/core6-last.json` にも実測を書き戻します
- リポジトリ正本を更新するときだけ `TOKFUEL_E2E_UPDATE_REPO_RECORDING=1` を付けます
- CI では SwiftPM の `.build` を cache し、再実行時のビルドを短縮します

UI の `accessibilityIdentifier` が変わると、記録上の必須 ID が見つからず失敗します（ログに `UI may have changed` と baseline ID 一覧が出ます）。

### 失敗時の PR コメント

CI で落ちたときは `App/Tests/E2E/comment-failure.sh` が次を PR コメントにまとめます。

- どのシナリオで落ちたか
- なぜ落ちたか（エラーと日本語の説明）
- 失敗時のスクリーンショットと挙動 GIF（0.1 秒/コマ）
- 前回成功時の実画面（orphan ブランチ `e2e-baselines` の popover / settings）

成功時は `App/Tests/E2E/publish-baselines.sh` が同じ実画面を `e2e-baselines` へ上書きします。失敗コメントの「成功 vs 失敗」はこの前回成功画像をスナップショットして並べます（同一コミットの `--ui-preview` は使いません）。まだ一度も緑になっていないときは「前回成功画面なし」と出ます。

失敗時の画像・GIF は `e2e-failure-images` orphan ブランチ経由で `raw.githubusercontent.com` に載せます（ui-preview と同じ方式）。

### ローカルの Accessibility 許可

初回はシステム設定 → プライバシーとセキュリティ → アクセシビリティで、ターミナル（または `TokfuelE2E`）を許可してください。CI では `App/Tests/E2E/grant-tcc.sh` が付与し、Screen Recording の Allow は `dismiss-tcc-prompt.sh` が押します。失敗時は 0.1 秒ごとの PNG を `ffmpeg` で `failure.mov` / `failure.gif` にし（再生も 0.1 秒/コマのまま）、PR コメントには挙動 GIF をインライン表示します。あわせて前回成功と失敗の並び比較も載せます。

### CI

[`.github/workflows/e2e.yml`](../../.github/workflows/e2e.yml) が macos-15 で同スクリプトを実行します。GitHub 上のチェック名は **E2E メニューバー** です。

PR に `e2e 🧪` ラベルを付けると再実行します（起動後にラベルは外れるので、何度でも付け直せます）。失敗コメントは前回分を hide（outdated）してから新規投稿します。
