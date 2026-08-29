# CI と検証

- 読み手: PR を出す開発者・エージェント
- 目的: ローカルと GitHub Actions の検証ゲートを揃える

## ローカル（必須）

```bash
swift test
swift build -c release
```

UI や配布に触れた変更では、必要に応じて `bash Scripts/build.sh` や `bash Scripts/screenshot.sh` も実行する。

## GitHub Actions

| Workflow | トリガー | 内容 |
|---|---|---|
| [ci.yml](../../.github/workflows/ci.yml) | `App/**` 等の変更 | macOS 上で `swift test` |
| [site-ci.yml](../../.github/workflows/site-ci.yml) | `Site/**` の変更 | Site のビルド |
| [ui-preview.yml](../../.github/workflows/ui-preview.yml) | ラベル `ui-preview 📸` | ポップオーバー等の画像プレビュー |
| [release.yml](../../.github/workflows/release.yml) | `versions/macos` 等 | 配布ビルド・公証・GitHub Release |
| [daily-release.yml](../../.github/workflows/daily-release.yml) | スケジュール | Sources 変更日の patch リリース PR |

`ci.yml` は path filter 付きのため、docs / Site だけの PR では Unit Test ジョブが走らない（未起動は Expected）。

## UI 変更の追加要件

`PopoverView`、`SettingsView`、`AboutView` など表示を変える PR では、同じ差分で次も更新する。

- `ScreenshotRenderer.allScreens()` のフィクスチャ
- [ui-preview.yml](../../.github/workflows/ui-preview.yml) の `ORDER` / `screen_title`
- Point-Free VRT 参考画像（`SNAPSHOT_TESTING_RECORD=all swift test --filter MatchesReference`）

詳細は [AGENTS.md](../../AGENTS.md) の検証ゲート節と [implementation](../../.agents/skills/implementation/SKILL.md) スキル。

## TestDocs

シナリオの正本は [`App/Tests/TestDocs/`](../../App/Tests/TestDocs/)。作業規範は [`AGENTS.md`](../../App/Tests/TestDocs/AGENTS.md)。
