---
id: Budget-15-daily-vs-monthly-independent
title: 日次と月次の予算が独立に判定される
primary_domain: Budget
platforms: [macOS]
status: ready
issue:
---

## シナリオ

日次予算と月次予算は、ホーム上で独立に判定され、独立に表示されます。

## 完了条件

- **E2E**
  - 日次と月次の予算行が同時に出せる
  - 一方の状態が他方の表示を強制しない
- **UT&IT**
  - 日次と月次の判定状態が独立して保持される

## 経路

### 日次と月次が独立

- **Given**：1日上限と月上限の両方がある
- **When**：ホームの予算行を見た時
- **Then**：今日と月の予算行がそれぞれ独立した状態で見える

## 対応済みPR

- （未作成）
