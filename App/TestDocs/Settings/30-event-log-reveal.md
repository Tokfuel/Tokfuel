---
id: Settings-30-event-log-reveal
title: イベントログフォルダを表示できる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

「ログを表示」を選ぶと、Finder がイベントログのフォルダを開きます。

## 完了条件

- **E2E**
  - ログを表示を選ぶと、イベントログのフォルダが開く

## 経路

### ログフォルダが開く

- **Given**：詳細が開いている
- **When**：ログを表示を選んだ時
- **Then**：イベントログのフォルダが前面に出る

## 対応済みPR

- （未作成）
