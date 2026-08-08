---
id: Cursor-05-top-session-rows
title: 高コストセッションに Cursor 行が混ざる
primary_domain: Cursor
platforms: [macOS]
status: ready
issue:
---

## シナリオ

Cursor の会話があるとき、高コストのセッションに Cursor 行がコスト順で混ざります。

## 完了条件

- **E2E**
  - 高コストのセッションに Cursor 行が見える

## 経路

### Cursor セッション行が出る

- **Given**：Cursor の高コスト会話がある
- **When**：高コストのセッションを見た時
- **Then**：Cursor 行が見える

## 対応済みPR

- （未作成）
