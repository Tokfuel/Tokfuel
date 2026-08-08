---
id: Budget-04-meter-ok-state
title: 平常時の予算メーターに消費と上限が見える
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

予算の平常状態では、メーター付近に消費と上限が読めます。

## 完了条件

- **E2E**
  - 平常時、消費と上限の表示が見える

## 経路

### 平常表示が出る

- **Given**：予算上限があり、消費がしきい値未満である
- **When**：ホームの予算行を見た時
- **Then**：消費と上限が読める

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
