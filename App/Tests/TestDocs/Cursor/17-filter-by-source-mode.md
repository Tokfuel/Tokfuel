---
id: Cursor-17-filter-by-source-mode
title: Claude のみのとき Cursor の行やヒントが隠れる
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

コストのソースが Claude のみのとき、Cursor のモデル行、セッション、ヒントは出ません。

## 完了条件

- **E2E**
  - Claude のみのとき、Cursor のモデル行とセッションとヒントが見えない

## 経路

### Cursor が隠れる

- **Given**：Cursor データを含むフィクスチャがあり、コストのソースが Claude のみである
- **When**：ホームを開いた時
- **Then**：Cursor のモデル行、セッション、ヒントが見えない

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
