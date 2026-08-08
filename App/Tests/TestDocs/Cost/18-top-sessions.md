---
id: Cost-18-top-sessions
title: 高コストのセッション一覧が表示される
primary_domain: Cost
platforms: [macOS]
status: in-progress
---

## シナリオ

ホームの「高コストのセッション」に、タイトルとソースと金額の行が出ます。

## 完了条件

- **E2E**
  - 高コストのセッションに行が見える
  - 各行にタイトルと金額が見える
- **VRT**
  - 高コストのセッションが見えるホーム末尾の状態が、プレビュー用フィクスチャとして固定されている

## 経路

### セッション行が見える

- **Given**：高コストセッションを含むフィクスチャがある
- **When**：ホームを開いた時
- **Then**：高コストのセッションに行が見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
