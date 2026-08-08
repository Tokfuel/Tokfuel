---
id: Settings-20-budget-monthly-limit
title: 月の上限を設定できる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

予算の「月の上限」に数値を入れると、ホームに月の予算ゲージが現れます。

## 完了条件

- **E2E**
  - 月の上限を入れると、ホームに月の予算表示が現れる

## 経路

### 月の上限を設定できる

- **Given**：設定の予算節が開いている
- **When**：月の上限に正の値を入れた時
- **Then**：ホームに月の予算行が見える

## 対応済みPR

- （未作成）
