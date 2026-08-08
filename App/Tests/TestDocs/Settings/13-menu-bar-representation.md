---
id: Settings-13-menu-bar-representation
title: メニューバーの表現を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

表現を金額、パーセント、リング、リングとパーセント、アイコンのみのあいだで、ライブプレビュー付きで選べます。

## 完了条件

- **E2E**
  - 表現の候補を切り替えられる
  - 設定上のライブプレビューが選んだ表現に追従する

## 経路

### 表現を切り替えられる

- **Given**：設定のメニューバー節が開いている
- **When**：表現を別の候補へ切り替えた時
- **Then**：ライブプレビューと実メニューバーが追従する

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
