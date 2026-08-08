---
id: Cost-07-chart-multi-source-legend
title: 複数ソース時に推移の凡例が出る
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

複数ソースがあるとき、日別棒グラフにソース別の凡例が表示されます。

## 完了条件

- **E2E**
  - 複数ソース時、推移にソース別凡例が見える

## 経路

### 凡例が見える

- **Given**：Claude と二次ソースのフィクスチャがある
- **When**：推移の日別棒を見た時
- **Then**：ソース別の凡例が見える

## 対応済みPR

- （未作成）
