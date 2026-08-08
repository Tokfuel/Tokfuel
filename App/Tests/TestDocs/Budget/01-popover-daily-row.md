---
id: Budget-01-popover-daily-row
title: 1日上限があるときホームに今日の予算行が出る
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

1日の上限が設定されているとき、ホームに予算（今日）の行とメーターが出ます。

## 完了条件

- **E2E**
  - 1日上限があるとき、ホームに今日の予算行とメーターが見える

## 経路

### 今日の予算行が出る

- **Given**：1日の上限が正の値である
- **When**：ホームを開いた時
- **Then**：予算（今日）の行とメーターが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
