---
id: Cursor-18-zero-cost-hidden-breakdown
title: 0 円の Cursor は内訳キャプションに載らない
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

Cursor が 0 円のとき、並べて表示の内訳キャプションに Cursor は載りません。

## 完了条件

- **E2E**
  - Cursor が 0 円のとき、内訳キャプションに Cursor が見えない

## 経路

### 0 円は内訳に出ない

- **Given**：並べて表示で、Cursor が 0 円である
- **When**：ヒーロー下の内訳を見た時
- **Then**：Cursor が見えない

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
