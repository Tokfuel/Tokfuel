---
id: Settings-16-menu-bar-percent-basis
title: 割合の基準を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

割合の基準を予算上限と過去 30 日の日次平均から選べます。

## 完了条件

- **E2E**
  - 割合の基準を予算上限と日次平均から切り替えられる

## 経路

### 割合の基準を切り替えられる

- **Given**：パーセント系の表現である
- **When**：割合の基準を切り替えた時
- **Then**：Settings の値が変わり、メニューバーの率が追従する

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
