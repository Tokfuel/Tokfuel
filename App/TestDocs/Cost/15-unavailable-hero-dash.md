---
id: Cost-15-unavailable-hero-dash
title: 取得不能時ヒーロー金額がダッシュになる
primary_domain: Cost
platforms: [macOS]
status: ready
issue:
---

## シナリオ

二次ソースのみで取得が劣化しているとき、ヒーロー金額はダッシュになります。

## 完了条件

- **E2E**
  - 取得不能なとき、ヒーロー金額がダッシュになる

## 経路

### ヒーローがダッシュになる

- **Given**：表示対象ソースが取得不能である
- **When**：ホームのヒーローを見た時
- **Then**：金額がダッシュである

## 対応済みPR

- （未作成）
