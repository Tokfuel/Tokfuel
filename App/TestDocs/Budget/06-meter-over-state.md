---
id: Budget-06-meter-over-state
title: 超過で予算メーターが超過状態になる
primary_domain: Budget
platforms: [macOS]
status: ready
---

## シナリオ

上限を超えると、メーターが超過色になり、超過額と警告アイコンが出ます。

## 完了条件

- **E2E**
  - 超過時、メーターが超過状態になる
  - 超過額が見える

## 経路

### 超過状態になる

- **Given**：消費が上限を超えている
- **When**：ホームの予算行を見た時
- **Then**：超過状態と超過額が見える

## 対応済みPR

- （未作成）
