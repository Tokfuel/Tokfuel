---
id: MenuBar-16-status-icon-only
title: メニューバーがアイコンのみになる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

表現がアイコンのみのとき、メニューバーはアイコンだけで、タイトル文字列は空になります。

## 完了条件

- **E2E**
  - 表現がアイコンのみのとき、メニューバーのタイトル文字列が空である
  - アイコン自体は見える

## 経路

### アイコンのみになる

- **Given**：表現がアイコンのみである
- **When**：メニューバー表示を読んだ時
- **Then**：タイトル文字列が空で、アイコンが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
