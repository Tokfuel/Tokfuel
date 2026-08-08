---
id: Settings-33-analytics-consent-first-run
title: 初回に利用状況送信の同意ダイアログが出る
primary_domain: Settings
platforms: [macOS]
status: in-progress
---

## シナリオ

初回起動時（未回答のとき）、利用状況の送信についての同意ダイアログが表示されます。

## 完了条件

- **E2E**
  - 未回答のとき、同意ダイアログが見える
- **VRT**
  - 画面 `analytics-consent` が、プレビュー用フィクスチャとして固定されている

## 経路

### 初回に同意ダイアログが出る

- **Given**：利用状況送信の回答が未設定である
- **When**：アプリを起動した時
- **Then**：同意ダイアログが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
