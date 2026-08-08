---
id: Cost-26-csv-export-disabled
title: レポート未取得時は CSV 書き出しが無効になる
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

レポートが未取得のとき、CSV を書き出すメニュー項目は無効になります。

## 完了条件

- **E2E**
  - レポート未取得のとき、CSV 書き出しが選べない

## 経路

### CSV が無効になる

- **Given**：レポートが未取得である
- **When**：ホームのメニューを見た時
- **Then**：CSV を書き出す項目が無効である

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
