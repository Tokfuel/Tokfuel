---
id: Budget-08-notification-warning
title: しきい値到達を通知で知らせる
primary_domain: Budget
platforms: [macOS]
status: ready
---

## シナリオ

知らせ方が通知のとき、しきい値到達で通知センターへ 1 回通知されます。

## 完了条件

- **E2E**
  - 知らせ方が通知のとき、しきい値到達で通知が 1 回出る

## 経路

### 警告通知が出る

- **Given**：知らせ方が通知で、消費がしきい値に達した直後である
- **When**：通知を確認した時
- **Then**：警告の通知が 1 回出ている

## 対応済みPR

- （未作成）
