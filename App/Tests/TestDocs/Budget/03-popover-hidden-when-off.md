---
id: Budget-03-popover-hidden-when-off
title: 上限未設定のとき予算セクションが隠れている
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

日も月も上限が未設定のとき、ホームに予算セクションは出ません。

## 完了条件

- **E2E**
  - 上限未設定のとき、ホームに予算セクションが見えない

## 経路

### 予算が隠れる

- **Given**：日と月の上限がどちらも未設定である
- **When**：ホームを開いた時
- **Then**：予算セクションが見えない

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
