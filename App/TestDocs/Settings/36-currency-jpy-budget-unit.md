---
id: Settings-36-currency-jpy-budget-unit
title: 円とレート取得後に予算入力の単位が円になる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

通貨が円でレートが取れたあと、予算入力欄の単位が円になります。

## 完了条件

- **E2E**
  - 円かつレート取得後、予算入力の単位が円になる

## 経路

### 予算単位が円になる

- **Given**：通貨が円で、為替レートが取得済みである
- **When**：設定の予算入力を見た時
- **Then**：単位が円である

## 対応済みPR

- （未作成）
