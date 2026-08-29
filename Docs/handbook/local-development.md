# ローカル開発

- 読み手: Tokfuel をビルド・実行する開発者・エージェント
- 前提: macOS 14+、Xcode / Swift 6

## 初回セットアップ

```bash
git clone https://github.com/Tokfuel/Tokfuel.git
cd Tokfuel
bash Scripts/setup.sh    # .githooks を core.hooksPath に登録
swift build
```

Claude Code の transcript が `~/.claude/projects/` にあれば、UI を実データで試せる。Claude のコスト分析には `python3`（Xcode CLT 付属）が必要。

## 日常のコマンド

| コマンド | 用途 |
|---|---|
| `swift test` | ユニットテスト（`App/Tests/UnitTests`） |
| `swift build -c release` | リリース構成のビルド |
| `swift run -c release` | ソースから直接起動 |
| `bash Scripts/build.sh` | `Tokfuel.app` を `/Applications` に配置して起動 |
| `bash Scripts/build.sh --debug` | デバッグビルド（設定のデバッグ節が有効） |
| `bash Scripts/screenshot.sh` | README / Site 用スクリーンショットを再生成 |

## スクリーンショット

`bash Scripts/screenshot.sh` は実 UI から PNG を生成し、次の両方へ書き出す。

- `Assets/screenshot.png`（README）
- `Site/Assets/images/screenshot.png`（GitHub Pages）

UI を変えた PR では、ローカルで生成して両方をコミットする。

## アプリアイコン

デザインの正本は [Tokfuel/icon](https://github.com/Tokfuel/icon)。本リポジトリはエクスポート PNG から ICNS を生成する。

```bash
swift Assets/make-icon.swift
```

## Site

```bash
cd Site && swift run
```

詳細は [Site/DESIGN.ja.md](../../Site/DESIGN.ja.md)。

## 詳細

人間向けの短い入口は [CONTRIBUTING.md](../../CONTRIBUTING.md)。
