---
id: MenuBar-09-status-amount-today
title: メニューバーに今日の金額が表示される
primary_domain: MenuBar
platforms: [macOS]
status: ready
issue:
---

## シナリオ

見る指標が「今日」のとき、メニューバーに今日のコスト金額が表示されます。

## 完了条件

- **E2E**
  - 見る指標が今日のとき、メニューバーに今日の金額が見える

## 経路

### 今日の金額がメニューバーに出る

- **Given**：見る指標が今日で、表現が金額である
- **When**：メニューバー表示を読んだ時
- **Then**：今日の金額が見える

## 対応済みPR

- （未作成）
