# Tests

アプリ向けの検証物をまとめる親ディレクトリ。

| パス | 役割 | `swift test` |
|------|------|--------------|
| [`UnitTests/`](UnitTests/) | ユニットテスト（Swift Testing） | 対象（`Package.swift` の `TokfuelTests`） |
| [`IntegrationTests/`](IntegrationTests/) | 結合テスト（後続で追加） | いまは対象外 |
| [`E2E/`](E2E/) | 通しテスト実装 | 対象外（別ランナー想定） |
| [`TestDocs/`](TestDocs/) | シナリオ設計（文書） | 対象外 |

実行するユニットテストだけを足すときは `UnitTests/` へ置く。
