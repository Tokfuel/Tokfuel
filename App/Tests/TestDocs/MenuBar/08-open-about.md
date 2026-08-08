---
id: MenuBar-08-open-about
title: メニューから Tokfuel についてを開ける
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがホームのメニューから「Tokfuel について」を選ぶと、About ウィンドウが開きます。

## 完了条件

- **E2E**
  - Tokfuel についてを選ぶと About ウィンドウが開く

## 経路

### About を開く

- **Given**：ホームが開いている
- **When**：メニューから Tokfuel についてを選んだ時
- **Then**：About ウィンドウが表示される

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
