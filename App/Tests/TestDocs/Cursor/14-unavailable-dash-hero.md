---
id: Cursor-14-unavailable-dash-hero
title: Cursor のみかつ劣化でヒーローがダッシュになる
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

Cursor のみで取得劣化のとき、ヒーロー金額はダッシュになります。

## 完了条件

- **E2E**
  - Cursor のみかつ劣化のとき、ヒーローがダッシュになる

## 経路

### ヒーローがダッシュ

- **Given**：コストのソースが Cursor のみで、取得が劣化している
- **When**：ホームのヒーローを見た時
- **Then**：金額がダッシュである

## 対応済みPR

- （未作成）
