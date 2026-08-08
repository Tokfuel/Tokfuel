---
id: Cost-25-csv-export-monthly
title: 月別 CSV を書き出せる
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

ホームのメニューから月別 CSV を書き出すと、月次集計のファイルを保存できます。

## 完了条件

- **E2E**
  - 月別 CSV の書き出しを選ぶと保存パネルが開く
  - 保存後に月次集計のファイルができる

## 経路

### 月別 CSV を保存できる

- **Given**：レポートが取得済みである
- **When**：CSV を書き出す（月別）を選んで保存した時
- **Then**：月次集計の CSV ファイルができる

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
