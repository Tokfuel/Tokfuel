---
id: Budget-13-alert-close
title: アラートを閉じられる
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

アラートの「閉じる」を選ぶと、アラートウィンドウが消えます。

## 完了条件

- **E2E**
  - 閉じるを選ぶと、アラートウィンドウが消える

## 経路

### アラートを閉じる

- **Given**：予算アラートが出ている
- **When**：閉じるを選んだ時
- **Then**：アラートウィンドウが見えなくなる

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
