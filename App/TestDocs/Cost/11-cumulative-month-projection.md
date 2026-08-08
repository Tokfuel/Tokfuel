---
id: Cost-11-cumulative-month-projection
title: 累積キャプションに月末の着地予測が出る
primary_domain: Cost
platforms: [macOS]
status: ready
issue:
---

## シナリオ

累積表示かつ暦月予算のとき、キャプションに月末の着地予測が出ます。

## 完了条件

- **E2E**
  - 条件を満たすとき、キャプションに月末の着地予測が見える

## 経路

### 着地予測が出る

- **Given**：累積と今月が選ばれ、暦月予算がある
- **When**：推移キャプションを見た時
- **Then**：月末の着地予測が見える

## 対応済みPR

- （未作成）
