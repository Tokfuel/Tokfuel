---
id: Budget-09-notification-over
title: 上限超過を通知で知らせる
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

知らせ方が通知のとき、上限超過で別内容の通知が 1 回出ます。

## 完了条件

- **E2E**
  - 知らせ方が通知のとき、超過で通知が 1 回出る

## 経路

### 超過通知が出る

- **Given**：知らせ方が通知で、消費が上限を超えた直後である
- **When**：通知を確認した時
- **Then**：超過の通知が 1 回出ている

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
