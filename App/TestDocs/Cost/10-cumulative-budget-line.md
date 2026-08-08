---
id: Cost-10-cumulative-budget-line
title: 累積グラフに予算の参照線が出る
primary_domain: Cost
platforms: [macOS]
status: ready
issue:
---

## シナリオ

累積表示かつ今月で、暦月の予算があるとき、グラフに予算の破線参照線とラベルが出ます。

## 完了条件

- **E2E**
  - 条件を満たすとき、累積グラフに予算の参照線が見える

## 経路

### 予算参照線が出る

- **Given**：累積と今月が選ばれ、暦月予算がある
- **When**：推移を見た時
- **Then**：予算の参照線とラベルが見える

## 対応済みPR

- （未作成）
