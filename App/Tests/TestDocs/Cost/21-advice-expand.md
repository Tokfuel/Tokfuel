---
id: Cost-21-advice-expand
title: 節約のヒントを展開できる
primary_domain: Cost
platforms: [macOS]
status: in-progress
---

## シナリオ

ユーザーがヒント行を操作すると、詳細テキストが展開されます。

## 完了条件

- **E2E**
  - ヒント行を操作すると詳細テキストが見える
- **VRT**
  - 画面 `popover-advice-expanded` が、プレビュー用フィクスチャとして固定されている

## 経路

### ヒントが展開される

- **Given**：節約のヒント行がある
- **When**：ヒント行を操作した時
- **Then**：詳細テキストが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
