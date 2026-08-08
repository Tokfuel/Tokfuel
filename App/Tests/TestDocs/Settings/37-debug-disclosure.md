---
id: Settings-37-debug-disclosure
title: デバッグを開くと診断用の設定が見える
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

設定の「デバッグ」を開くと、イベントログなど診断用の項目が見えます。

観測するのは、デバッグを開いたあとに診断用の項目が見えることまでです。見た目の固定は完了条件の VRT で扱います。

## 完了条件

- **E2E**
  - デバッグを開くと、診断用の設定項目が見える
- **VRT**
  - 画面 `settings-debug` が、プレビュー用フィクスチャとして固定されている

## 経路

### デバッグが開く

- **Given**：設定が開いている
- **When**：デバッグを開いた時
- **Then**：イベントログなど診断用の項目が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
