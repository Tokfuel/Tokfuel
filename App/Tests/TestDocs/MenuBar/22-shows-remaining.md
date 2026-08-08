---
id: MenuBar-22-shows-remaining
title: 予算までの残り表示に切り替えられる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

「予算までの残りを表示」がオンのとき、メニューバーは残額または残率の表示になります。

## 完了条件

- **E2E**
  - 予算までの残りを表示がオンのとき、残りとして読める表示になる

## 経路

### 残り表示になる

- **Given**：予算までの残りを表示がオンで、予算上限がある
- **When**：メニューバー表示を読んだ時
- **Then**：残りとして読める金額または率が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
