---
id: Cost-24-csv-export-daily
title: 日別 CSV を書き出せる
primary_domain: Cost
platforms: [macOS]
status: ready
---

## シナリオ

ホームのメニューから日別 CSV を書き出すと、保存パネルが開きファイルを保存できます。

## 完了条件

- **E2E**
  - 日別 CSV の書き出しを選ぶと保存パネルが開く
  - 保存後に日別集計のファイルができる

## 経路

### 日別 CSV を保存できる

- **Given**：レポートが取得済みである
- **When**：CSV を書き出す（日別）を選んで保存した時
- **Then**：日別集計の CSV ファイルができる

## 対応済みPR

- （未作成）
