---
id: Cursor-11-degraded-warning
title: Cursor 取得劣化時に警告が出る
primary_domain: Cursor
platforms: [macOS]
status: ready
---

## シナリオ

Cursor の取得が劣化しているとき、ヒーロー下に警告文と警告アイコンが出ます。

## 完了条件

- **E2E**
  - 取得劣化時、ヒーロー下に Cursor 警告が見える

## 経路

### 劣化警告が出る

- **Given**：Cursor 取得が劣化している
- **When**：ホームを開いた時
- **Then**：Cursor 警告が見える

## 対応済みPR

- （未作成）
