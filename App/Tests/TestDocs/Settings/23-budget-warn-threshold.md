---
id: Settings-23-budget-warn-threshold
title: 警告しきい値を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

警告しきい値を 70%、80%、90% から選べます。

## 完了条件

- **E2E**
  - 警告しきい値を 70%、80%、90% から切り替えられる

## 経路

### しきい値を切り替えられる

- **Given**：設定の予算節が開いている
- **When**：警告しきい値を別の候補へ切り替えた時
- **Then**：Settings のしきい値が追従する

## 対応済みPR

- （未作成）
