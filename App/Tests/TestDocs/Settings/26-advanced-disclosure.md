---
id: Settings-26-advanced-disclosure
title: 詳細を開くと高度な設定が見える
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

設定の「詳細」を開くと、レポート言語や Claude ディレクトリなどが見えます。

## 完了条件

- **E2E**
  - 詳細を開くと、高度な設定項目が見える
- **VRT**
  - 画面 `settings-advanced` が、プレビュー用フィクスチャとして固定されている

## 経路

### 詳細が開く

- **Given**：設定が開いている
- **When**：詳細を開いた時
- **Then**：レポート言語や Claude ディレクトリが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
