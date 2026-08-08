---
id: MenuBar-07-footer-quit
title: メニューから Tokfuel を終了できる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがホームのメニューから「Tokfuel を終了」を選ぶと、アプリが終了します。

## 完了条件

- **E2E**
  - Tokfuel を終了を選ぶとアプリが終了する

## 経路

### 終了メニューでアプリが終わる

- **Given**：ホームが開いている
- **When**：メニューから Tokfuel を終了を選んだ時
- **Then**：アプリプロセスが終了している

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
