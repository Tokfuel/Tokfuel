---
id: Cost-12-jpy-formatting
title: 円表示のときホームの金額が円表記になる
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

通貨が円のとき、ホーム内の金額や軸が円表記になります。

## 完了条件

- **E2E**
  - 通貨が円のとき、ホームの金額が円表記になる
- **VRT**
  - 画面 `popover-jpy` が、プレビュー用フィクスチャとして固定されている

## 経路

### 円表記になる

- **Given**：通貨が円である
- **When**：ホームの金額表示を見た時
- **Then**：円表記になっている

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
