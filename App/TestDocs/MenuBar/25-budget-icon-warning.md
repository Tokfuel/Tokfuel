---
id: MenuBar-25-budget-icon-warning
title: 予算しきい値到達でメニューバーアイコンが警告色になる
primary_domain: MenuBar
platforms: [macOS]
status: ready
issue:
---

## シナリオ

予算の警告しきい値に達すると、メニューバーアイコンがオレンジ系の警告色になります。

## 完了条件

- **E2E**
  - しきい値到達時、メニューバーアイコンが警告色になる

## 経路

### しきい値で警告色になる

- **Given**：予算上限があり、消費が警告しきい値以上である
- **When**：メニューバーアイコンを見た時
- **Then**：警告色になっている

## 対応済みPR

- （未作成）
