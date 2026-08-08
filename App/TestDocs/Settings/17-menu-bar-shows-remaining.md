---
id: Settings-17-menu-bar-shows-remaining
title: 予算までの残りを表示を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

「予算までの残りを表示」を切り替えると、メニューバーが残額または残率の見え方に変わります。

## 完了条件

- **E2E**
  - 予算までの残りを表示をオンにすると、残りとして読める表示になる

## 経路

### 残り表示を切り替えられる

- **Given**：予算上限がある
- **When**：予算までの残りを表示をオンにした時
- **Then**：メニューバーが残り表示になる

## 対応済みPR

- （未作成）
