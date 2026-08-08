---
id: MenuBar-02-close-outside
title: ホーム外をクリックするとポップオーバーが閉じる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがホーム（ポップオーバー）を開いたあと、他のアプリ側をクリックすると、ホームが閉じます。

観測するのはホームが閉じることまでです。

## 完了条件

- **E2E**
  - ホーム表示中にホーム外をクリックすると、ホームが閉じる

## 経路

### ホーム外クリックで閉じる

- **Given**：ホームが開いている
- **When**：ホーム外（他アプリ側）をクリックした時
- **Then**：ホームが閉じている

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
