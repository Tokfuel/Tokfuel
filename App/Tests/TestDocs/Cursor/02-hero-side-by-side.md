---
id: Cursor-02-hero-side-by-side
title: 並べて表示でヒーロー下に Cursor 金額が並ぶ
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

並べて表示のとき、ヒーロー下キャプションに Cursor の金額が並びます。

## 完了条件

- **E2E**
  - 並べて表示のとき、ヒーロー下に Cursor 金額が見える

## 経路

### Cursor 金額が並ぶ

- **Given**：並べて表示で、Cursor に正の金額がある
- **When**：ホームを開いた時
- **Then**：ヒーロー下に Cursor 金額が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
