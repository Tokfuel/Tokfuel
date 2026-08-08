---
id: MenuBar-05-footer-last-updated
title: フッターに最終更新時刻が表示される
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがホームを開くと、フッターに最終更新時刻（更新 HH:MM）が表示されます。

## 完了条件

- **E2E**
  - ホームのフッターに最終更新時刻が見える

## 経路

### 最終更新時刻が見える

- **Given**：少なくとも 1 回集計が完了している
- **When**：ホームを開いた時
- **Then**：フッターに更新時刻が見える

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
