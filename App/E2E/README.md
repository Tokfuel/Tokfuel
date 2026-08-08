# E2E

アプリ（`App/Tokfuel`）向けの通しテスト実装を置く場所です。

シナリオ設計の正本は [`../TestDocs`](../TestDocs/) です。UT / IT は [`../Tests`](../Tests/) に置きます。

## 方針

- Maestro / Appium / 別リポジトリは持ち込まない
- 見た目の固定は E2E ではなく VRT（`ScreenshotRenderer` / `ui-preview`）に置く
- 操作は macOS Accessibility（AX）で行う
- 詳細な優先順位は [`../TestDocs/README.md`](../TestDocs/README.md) の「担保手段」節

## コア 6

次のシナリオを `App/E2E/run-core6.sh` がまとめて回します。

- `MenuBar-01-open-home`
- `Cost-01-chart-style`
- `Cost-02-period-switch`
- `Cost-03-model-list`
- `Settings-01-open`
- `Settings-02-reflect`

```bash
bash App/E2E/run-core6.sh
```

デバッグビルドの Tokfuel を `--e2e-fixture` で起動し、`TokfuelE2E` ドライバがメニューバーを AX 操作します。実ユーザーの `~/Library/Application Support/Tokfuel` は触りません。

`--e2e-fixture` では NSPopover が AX ツリーに載らないため、ステータス項目のクリックで同じホーム UI を `NSPanel` に出します（本番の見た目経路は従来どおり NSPopover）。

### ローカルの Accessibility 許可

初回はシステム設定 → プライバシーとセキュリティ → アクセシビリティで、ターミナル（または `TokfuelE2E`）を許可してください。CI では `App/E2E/grant-tcc.sh` が付与します。

### CI

[`.github/workflows/e2e.yml`](../../.github/workflows/e2e.yml) が macos-15 で同スクリプトを実行します。
