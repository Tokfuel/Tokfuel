---
id: Cursor-10-advice-hidden-when-degraded
title: Cursor 取得劣化時は Cursor ヒントが出ない
primary_domain: Cursor
platforms: [macOS]
status: ready
---

## シナリオ

Cursor の取得が劣化しているとき、節約のヒントに Cursor 由来の行は出ません。

## 完了条件

- **E2E**
  - 取得劣化時、Cursor 由来のヒントが見えない

## 経路

### 劣化時ヒントが隠れる

- **Given**：Cursor 取得が劣化している
- **When**：節約のヒントを見た時
- **Then**：Cursor 由来のヒントが見えない

## 対応済みPR

- （未作成）
