---
id: Settings-09-cost-source-side-by-side
title: コストのソースを並べて表示にできる
primary_domain: Settings
platforms: [macOS]
status: in-progress
---

## シナリオ

コストのソースを並べて表示にすると、ホームがソース別の内訳表示になります。

## 完了条件

- **E2E**
  - 並べて表示のとき、ホームにソース別内訳が見える
- **VRT**
  - 画面 `popover` が、プレビュー用フィクスチャとして固定されている

## 経路

### 並べて表示になる

- **Given**：複数ソースのフィクスチャがある
- **When**：コストのソースを並べて表示にした時
- **Then**：ホームにソース別内訳が見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
