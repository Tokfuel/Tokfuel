---
id: Budget-02-popover-monthly-row
title: 月上限があるときホームに月の予算行が出る
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

月の上限が設定されているとき、ホームに予算（今月）または予算（30日）の行が出ます。

## 完了条件

- **E2E**
  - 月上限があるとき、ホームに月の予算行が見える

## 経路

### 月の予算行が出る

- **Given**：月の上限が正の値である
- **When**：ホームを開いた時
- **Then**：月の予算行が見える

## 対応済みPR

- （未作成）
