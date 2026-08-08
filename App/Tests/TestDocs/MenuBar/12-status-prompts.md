---
id: MenuBar-12-status-prompts
title: メニューバーにプロンプト数が表示される
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

見る指標が「プロンプト数」のとき、メニューバーにプロンプト数が表示されます。

## 完了条件

- **E2E**
  - 見る指標がプロンプト数のとき、メニューバーにプロンプト数が見える

## 経路

### プロンプト数がメニューバーに出る

- **Given**：見る指標がプロンプト数である
- **When**：メニューバー表示を読んだ時
- **Then**：プロンプト数が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
