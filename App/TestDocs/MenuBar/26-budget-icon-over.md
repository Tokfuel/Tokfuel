---
id: MenuBar-26-budget-icon-over
title: 予算超過でメニューバーアイコンが超過色になる
primary_domain: MenuBar
platforms: [macOS]
status: ready
---

## シナリオ

予算を超過すると、メニューバーアイコンが赤系の超過色になります。

## 完了条件

- **E2E**
  - 予算超過時、メニューバーアイコンが超過色になる

## 経路

### 超過で超過色になる

- **Given**：予算上限があり、消費が上限を超えている
- **When**：メニューバーアイコンを見た時
- **Then**：超過色になっている

## 対応済みPR

- （未作成）
