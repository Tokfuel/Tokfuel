# Demo（#155）

インストール前にポップオーバー相当を辿る**閲覧デモ**。
正本の仕様は [Issue #155](https://github.com/Tokfuel/Tokfuel/issues/155)。

## 思想

- **正本は Swift の UI 構成**（`Demo/DemoUI`）。Web 用に別デザインの HTML を育てることは本線にしない。
- 「そのまま」は **ソース共有**を指す。Apple の SwiftUI ランタイム自体は Wasm に出せない。
- 描画ホストは `Demo/DemoSwiftUI` を **ローカル `TokamakDOM` シム**として使う（JavaScriptKit）。上流の Tokamak は Swift 6.2 wasip1 ではまだビルドできないため、載せ替え可能な境界だけ先に切ってある。
- **HTML / CSS / JS は参考モック**。大きな変更は DemoUI 側だけにする。

フィクスチャ専用。Claude / Cursor / Codex の利用データは読み取らず、送信もしない。

## 構成

| パス | 役割 |
|------|------|
| `DemoUI/` | 正本。`DemoPopoverView` + `DemoFixtures` |
| `DemoSwiftUI/` | ローカル `TokamakDOM` シム（ノード木 → DOM） |
| `wasm/` | Wasm ホスト + `hosted/` 成果物 |
| `html/` | 参考モック |
| `compare.html` | `/demo/`。Wasm 本線、HTML 参考 |

## ローカル

```bash
bash Scripts/build-wasm-demo.sh
bash Scripts/demo-serve.sh
# → http://127.0.0.1:8765/demo/wasm/
```

### ビルド要件

1. swiftly の OSS Swift（例: 6.2.4）
2. Swift SDK for WebAssembly（例: `swift-6.2.4-RELEASE_wasm`）
3. Wasm 向け clang（Homebrew `llvm`）
