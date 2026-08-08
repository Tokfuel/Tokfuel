---
id: Cursor-09-advice-unpriced-models
title: 価格表に無い Cursor モデルのヒントが出る
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

価格表に無い Cursor モデルがあるとき、高い重要度のヒントが出ます。

## 完了条件

- **E2E**
  - 未価格モデルがあるとき、そのヒントが見える

## 経路

### 未価格ヒントが出る

- **Given**：価格表に無い Cursor モデルを含むフィクスチャがある
- **When**：節約のヒントを見た時
- **Then**：未価格モデルのヒントが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
