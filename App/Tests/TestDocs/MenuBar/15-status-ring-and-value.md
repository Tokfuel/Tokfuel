---
id: MenuBar-15-status-ring-and-value
title: メニューバーにリングとパーセントが並ぶ
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

表現がリングとパーセントのとき、メニューバーにリングと数値が並んで表示されます。

## 完了条件

- **E2E**
  - 表現がリングとパーセントのとき、リングと数値が並んで見える

## 経路

### リングと数値が並ぶ

- **Given**：表現がリングとパーセントである
- **When**：メニューバー表示を読んだ時
- **Then**：リングとパーセント数値の両方が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
