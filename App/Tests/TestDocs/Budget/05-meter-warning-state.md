---
id: Budget-05-meter-warning-state
title: しきい値到達で予算メーターが警告状態になる
primary_domain: Budget
platforms: [macOS]
status: ready
---

## シナリオ

警告しきい値に達すると、メーターが警告色になり、残りが表示されます。

## 完了条件

- **E2E**
  - しきい値到達時、メーターが警告状態になる
  - 残り表示が見える

## 経路

### 警告状態になる

- **Given**：消費が警告しきい値以上で上限未満である
- **When**：ホームの予算行を見た時
- **Then**：警告状態と残りが見える

## 対応済みPR

- （未作成）
