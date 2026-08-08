# 担保手段

TestDocs の完了条件で使う手段の優先と境界です。シナリオ MD の書き方は [`_TEMPLATE.md`](_TEMPLATE.md) を正とします。

## 原則

1. **E2E** でユーザー操作に近い通しを担保する
2. **UT&IT** は、通しだけでは脆い計算や表示用モデルの組み立てを補助する
3. **VRT** は、見た目の固定が要る観点だけに足す

同じ観測を手段のあいだで二重にテストしない。E2E で既に観測できる表示を、同じ期待のまま UT&IT に複製しない。

## E2E

シナリオの主たる完了条件です。

- 置き場: [`../E2E`](../E2E/)
- Maestro / Appium / 別リポジトリは持ち込まない
- ウィンドウサーバが必要（手元の Mac、または ui-preview と同じ種類の CI ランナー）
- 見た目のピクセル回帰は E2E ではなく VRT に置く
- 実ユーザーの `~/Library/Application Support/Tokfuel` は触らない。フィクスチャ注入で再現する

## UT&IT

通しでは観測しづらい振る舞いを補助します。

- 置き場: [`../Tests`](../Tests/)
- 実行: `swift test`
- 当面はフィクスチャと部分モックで完結してよい
- Then の主検証は Store / Settings / 表示用の状態とする

## VRT

見た目の回帰を止めます。

- 当面の土台: `ScreenshotRenderer` と `ui-preview`（人間レビュー用の絵出し）
- ピクセル比較の自動 VRT は後続 Issue で足してよい。完了条件の VRT は「対象画面がフィクスチャとして固定されている」ことを指す
- 新規パッケージや外部 VRT SaaS は、オーナー承認なしでは入れない
- UI を変える PR では、既存どおり `ScreenshotRenderer.allScreens()` と `ui-preview.yml` を同じ差分で更新する

## 対象外

- Site（`Site/`）のシナリオ。別系統で必要になったら `Site/` 側に置く
- 実ユーザーの `~/Library/Application Support/Tokfuel` を触るテスト
- 利用データを Mac の外へ出す検証
