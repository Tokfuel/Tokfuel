---
id: Settings-05-cost-source-combined
title: コストのソースを合算にできる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

コストのソースを合算にすると、ホームは全ソース合計を表示します。

## 完了条件

- **E2E**
  - 合算のとき、ホームが全ソース合計を表示する
- **VRT**
  - 画面 `popover-combined` が、プレビュー用フィクスチャとして固定されている

## 経路

### 合算になる

- **Given**：複数ソースのフィクスチャがある
- **When**：コストのソースを合算にした時
- **Then**：ホームが合計表示になる

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
