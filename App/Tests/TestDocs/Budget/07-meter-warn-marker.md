---
id: Budget-07-meter-warn-marker
title: 予算メーターに警告しきい値の目盛りが出る
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

予算メーター上に、警告しきい値の目盛り線が引かれます。

## 完了条件

- **E2E**
  - 予算メーターに警告しきい値の目盛りが見える

## 経路

### 目盛りが見える

- **Given**：予算上限と警告しきい値がある
- **When**：ホームの予算メーターを見た時
- **Then**：しきい値の目盛りが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
