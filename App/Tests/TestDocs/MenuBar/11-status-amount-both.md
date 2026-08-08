---
id: MenuBar-11-status-amount-both
title: メニューバーに今日と今月の金額が表示される
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

見る指標が「今日と今月」のとき、メニューバーに両方の金額が表示されます。

## 完了条件

- **E2E**
  - 見る指標が今日と今月のとき、メニューバーに両方の金額が見える

## 経路

### 今日と今月が並ぶ

- **Given**：見る指標が今日と今月で、表現が金額である
- **When**：メニューバー表示を読んだ時
- **Then**：今日と今月の両方の金額が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
