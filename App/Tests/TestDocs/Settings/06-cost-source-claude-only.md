---
id: Settings-06-cost-source-claude-only
title: コストのソースを Claude のみにできる
primary_domain: Settings
platforms: [macOS]
status: in-progress
---

## シナリオ

コストのソースを Claude のみにすると、ホームは Claude のコストだけを表示します。

## 完了条件

- **E2E**
  - Claude のみのとき、ホームに Claude 以外のソース金額が主表示されない
- **VRT**
  - コストソースが Claude のみのときのホームが、プレビュー用フィクスチャとして固定されている
  - コストソースが Claude のみのときの設定画面が、プレビュー用フィクスチャとして固定されている

## 経路

### Claude のみになる

- **Given**：複数ソースのフィクスチャがある
- **When**：コストのソースを Claude のみにした時
- **Then**：ホームが Claude のみの表示になる

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
