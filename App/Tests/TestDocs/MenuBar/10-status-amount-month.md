---
id: MenuBar-10-status-amount-month
title: メニューバーに今月の金額が表示される
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

見る指標が「今月」のとき、メニューバーに今月のコスト金額が表示されます。

## 完了条件

- **E2E**
  - 見る指標が今月のとき、メニューバーに今月の金額が見える

## 経路

### 今月の金額がメニューバーに出る

- **Given**：見る指標が今月で、表現が金額である
- **When**：メニューバー表示を読んだ時
- **Then**：今月の金額が見える

## 対応済みPR

- （未作成）
