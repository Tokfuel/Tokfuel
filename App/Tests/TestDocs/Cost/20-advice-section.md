---
id: Cost-20-advice-section
title: 節約のヒントセクションが表示される
primary_domain: Cost
platforms: [macOS]
status: in-progress
---

## シナリオ

ホームに「節約のヒント」セクションがあり、ヒント行が並びます。

## 完了条件

- **E2E**
  - 節約のヒントセクションが見える
  - ヒント行が 1 行以上見える
- **VRT**
  - 画面 `popover-advice`、`popover-scrolled` が、プレビュー用フィクスチャとして固定されている

## 経路

### ヒントセクションが見える

- **Given**：ヒントを出せるフィクスチャがある
- **When**：ホームを開いた時
- **Then**：節約のヒントと行が見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
