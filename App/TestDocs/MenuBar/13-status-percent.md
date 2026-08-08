---
id: MenuBar-13-status-percent
title: メニューバーにパーセント表示が出る
primary_domain: MenuBar
platforms: [macOS]
status: ready
issue:
---

## シナリオ

表現がパーセントのとき、メニューバーに消費率または残率の数値が表示されます。

## 完了条件

- **E2E**
  - 表現がパーセントのとき、メニューバーに割合の数値が見える

## 経路

### パーセントが見える

- **Given**：表現がパーセントで、割合の分母が取れる
- **When**：メニューバー表示を読んだ時
- **Then**：割合の数値が見える

## 対応済みPR

- （未作成）
