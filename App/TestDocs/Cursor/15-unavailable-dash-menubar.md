---
id: Cursor-15-unavailable-dash-menubar
title: Cursor のみかつ劣化でメニューバーがダッシュになる
primary_domain: Cursor
platforms: [macOS]
status: ready
issue:
---

## シナリオ

Cursor のみで取得劣化のとき、メニューバーもダッシュになります。

## 完了条件

- **E2E**
  - Cursor のみかつ劣化のとき、メニューバーがダッシュになる

## 経路

### メニューバーがダッシュ

- **Given**：コストのソースが Cursor のみで、取得が劣化している
- **When**：メニューバー表示を読んだ時
- **Then**：金額がダッシュである

## 対応済みPR

- （未作成）
