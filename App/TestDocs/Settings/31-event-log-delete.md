---
id: Settings-31-event-log-delete
title: 全イベントログを削除できる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

「全イベントを削除」を選ぶと、ローカルのイベントログが消えます。

## 完了条件

- **E2E**
  - 全イベントを削除を選ぶと、ローカルのイベントログが消える

## 経路

### イベントを削除できる

- **Given**：イベントログが存在する
- **When**：全イベントを削除を選んだ時
- **Then**：ローカルのイベントログが無くなっている

## 対応済みPR

- （未作成）
