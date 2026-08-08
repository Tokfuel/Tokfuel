# Demo（#155 spike）

インストール前にポップオーバー相当を辿る**閲覧デモ**の両スタック試作。
正本の仕様は [Issue #155](https://github.com/Tokfuel/Tokfuel/issues/155)。

## 何があるか

| パス | 内容 |
|------|------|
| `fixtures.json` | 共通フィクスチャ（`ScreenshotRenderer` と同じ数値） |
| `html/` | 静的 HTML / CSS / JS デモ |
| `wasm/` | SwiftWasm（JavaScriptKit）デモのソース |
| `wasm/hosted/` | `Scripts/build-wasm-demo.sh` の静的成果物 |
| `compare.html` | 両方への入口（公開時は `/demo/`） |

どちらもフィクスチャ専用。Claude / Cursor / Codex の利用データは読み取らず、送信もしない。

## ローカルで触る

```bash
# 任意: Wasm 成果物を更新
bash Scripts/build-wasm-demo.sh

# 比較入口をサーブ
bash Scripts/demo-serve.sh
# → http://127.0.0.1:8765/demo/
```

HTML だけなら `build-wasm-demo.sh` は不要（Wasm ページにビルド手順が出る）。

## SwiftWasm ビルド要件

Xcode 付属の `/usr/bin/swift` は `wasm32-unknown-wasip1` を扱えない。次が必要。

1. [swiftly](https://www.swift.org/install/macos/) の OSS Swift（例: 6.2.4）を PATH 先頭へ
2. 対応する Swift SDK for WebAssembly（例: `swift-6.2.4-RELEASE_wasm`）
3. Wasm 向け clang（Homebrew `llvm` で可）

ElementaryUI は Swift 6.3 前提のため、このスパイクでは JavaScriptKit 直の薄い DOM 実装にした。

## 公開面

GitHub Pages では Site ビルド成果に `/demo/` を載せる。

- `/demo/` — 比較入口
- `/demo/html/` — HTML デモ
- `/demo/wasm/` — SwiftWasm デモ（`hosted/` があるとき）

追従は `main` への Site / Demo 変更で Pages が更新される想定（リリース専用パイプラインは後回し）。

## 比較観点

スパイク完了時に、次で本線を決める。

1. 見た目の近さ（ヒーロー、予算、モデル別）
2. 操作の滑らかさ（開閉、設定 / About 遷移）
3. ビルドと依存の重さ
4. Pages への載せやすさ
5. App との距離（今後の保守）

この PR で両方を永久併記する前提にはしない。結果は Issue #155 にコメントする。
