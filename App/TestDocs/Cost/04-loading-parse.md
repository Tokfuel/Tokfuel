---
id: Cost-04-loading-parse
title: レポート未取得時に解析中表示が出る
primary_domain: Cost
platforms: [macOS]
status: ready
issue:
---

## シナリオ

レポートがまだ無いとき、ホームに「解析中…」の読み込み表示が出ます。

## 完了条件

- **E2E**
  - レポート未取得のとき、解析中の表示が見える

## 経路

### 解析中が見える

- **Given**：レポートが未取得である
- **When**：ホームを開いた時
- **Then**：解析中の表示が見える

## 対応済みPR

- （未作成）
