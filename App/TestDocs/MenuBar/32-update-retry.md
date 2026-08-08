---
id: MenuBar-32-update-retry
title: 更新失敗時に再試行できる
primary_domain: MenuBar
platforms: [macOS]
status: ready
issue:
---

## シナリオ

アップデート処理が失敗すると、フッターが警告表示と再試行操作になります。

## 完了条件

- **E2E**
  - 更新失敗時、再試行操作が見える

## 経路

### 再試行が出る

- **Given**：アップデートが失敗した状態である
- **When**：ホームのフッターを見た時
- **Then**：再試行操作が見える

## 対応済みPR

- （未作成）
