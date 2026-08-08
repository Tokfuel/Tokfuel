---
id: MenuBar-18-gauge-shape-tank
title: ゲージの形がタンクのとき給油機が下から塗られる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ゲージの形がタンクのとき、メニューバーの給油機アイコンが下から塗られる形で割合を示します。

## 完了条件

- **E2E**
  - ゲージの形がタンクのとき、給油機アイコンの塗りで割合が見える

## 経路

### タンク形のゲージが見える

- **Given**：表現にリングが含まれ、ゲージの形がタンクである
- **When**：メニューバー表示を読んだ時
- **Then**：給油機アイコンの塗りで割合が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
