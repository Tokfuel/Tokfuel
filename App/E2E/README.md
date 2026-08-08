# E2E

アプリ（`App/Tokfuel`）向けの通しテスト実装を置く場所です。

シナリオ設計の正本は [`../TestDocs`](../TestDocs/) です。どの観点に E2E が要るかは、シナリオ MD の完了条件で決めます。UT / IT は [`../Tests`](../Tests/) に置きます。

## 方針

- Maestro / Appium / 別リポジトリは持ち込まない
- 見た目の固定は E2E ではなく VRT（`ScreenshotRenderer` / `ui-preview`）に置く
- 最初の候補は起動スモークと主要画面到達に限る
- 詳細な優先順位は [`../TestDocs/README.md`](../TestDocs/README.md) の「担保手段」節

このディレクトリにテスト実装を足すときは、対応する TestDocs シナリオを `ready` 以上にしてから進めます。
