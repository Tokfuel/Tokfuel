---
id: Budget-14-alert-both-channels
title: 通知とアラートウィンドウの両方で知らせる
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

知らせ方が通知とアラートウィンドウのとき、しきい値到達や超過で両方が出ます。

## 完了条件

- **E2E**
  - 知らせ方が両方のとき、通知とアラートの両方が出る

## 経路

### 両方が出る

- **Given**：知らせ方が通知とアラートウィンドウである
- **When**：しきい値到達または超過が起きた時
- **Then**：通知とアラートの両方が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
