---
id: MenuBar-17-gauge-shape-ring
title: ゲージの形がリングのとき円形インジケーターになる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ゲージの形がリングのとき、メニューバーのゲージは円形インジケーターとして描画されます。

## 完了条件

- **E2E**
  - ゲージの形がリングのとき、円形のゲージが見える

## 経路

### リング形のゲージが見える

- **Given**：表現にリングが含まれ、ゲージの形がリングである
- **When**：メニューバー表示を読んだ時
- **Then**：円形のゲージが見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
