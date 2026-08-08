# E2E

アプリ（`App/Tokfuel`）向けの通しテスト実装を置く場所です。

シナリオ設計の正本は [`../TestDocs`](../TestDocs/) です。UT / IT は [`../Tests`](../Tests/) に置きます。

## 方針

- Maestro / Appium / 別リポジトリは持ち込まない
- 見た目の固定は E2E ではなく VRT（`ScreenshotRenderer` / `ui-preview`）に置く
- 最初の実装は起動スモークと主要画面到達（IT-F010-LC01）
- 詳細な優先順位は [`../TestDocs/coverage-strategy.md`](../TestDocs/coverage-strategy.md)

## 実行

```bash
bash App/E2E/run-smoke.sh
```

デバッグビルドの Tokfuel を `--ui-preview` で起動し、[`expected-screens.txt`](expected-screens.txt) の画面がすべて非空 PNG として書き出されることを確かめます。出力先を残すときは `TOKFUEL_E2E_OUT=/tmp/tokfuel-e2e bash App/E2E/run-smoke.sh` とします。

ウィンドウサーバが必要です（手元の Mac、または ui-preview と同じ種類の CI ランナー）。
