---
id: Settings-21-budget-daily-limit
title: 1日の上限を設定できる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

予算の「1日の上限」に数値を入れると、ホームに今日の予算行が現れます。

## 完了条件

- **E2E**
  - 1日の上限を入れると、ホームに今日の予算行が現れる

## 経路

### 1日の上限を設定できる

- **Given**：設定の予算節が開いている
- **When**：1日の上限に正の値を入れた時
- **Then**：ホームに今日の予算行が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
