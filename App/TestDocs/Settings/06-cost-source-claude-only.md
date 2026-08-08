---
id: Settings-06-cost-source-claude-only
title: コストのソースを Claude のみにできる
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

コストのソースを Claude のみにすると、ホームは Claude のコストだけを表示します。

## 完了条件

- **E2E**
  - Claude のみのとき、ホームに Claude 以外のソース金額が主表示されない

## 経路

### Claude のみになる

- **Given**：複数ソースのフィクスチャがある
- **When**：コストのソースを Claude のみにした時
- **Then**：ホームが Claude のみの表示になる

## 対応済みPR

- （未作成）
