---
id: Cursor-16-unavailable-side-by-side
title: 並べて表示で Cursor 側だけダッシュになる
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

並べて表示で Cursor だけ劣化しているとき、Cursor 側だけダッシュになります。

## 完了条件

- **E2E**
  - 並べて表示で Cursor 側だけがダッシュになる

## 経路

### Cursor 側だけダッシュ

- **Given**：並べて表示で、Cursor だけ取得劣化している
- **When**：ホームまたはメニューバーを見た時
- **Then**：Cursor 側だけがダッシュである

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
