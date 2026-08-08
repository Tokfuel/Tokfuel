---
id: MenuBar-27-tooltip
title: メニューバーアイコンのツールチップに指標説明が出る
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがメニューバーアイコンにポインタを合わせると、ツールチップに現在の指標の説明が出ます。

## 完了条件

- **E2E**
  - アイコンのツールチップに指標の説明が見える

## 経路

### ツールチップが出る

- **Given**：メニューバーにアイコンがある
- **When**：アイコンにポインタを合わせた時
- **Then**：指標の説明を含むツールチップが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
