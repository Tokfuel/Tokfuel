---
id: Settings-35-menu-bar-preview-note
title: 選べない表現のとき説明文が出る
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

メニューバー節で、選べない表現や分母不足のとき、フッターに説明文が出ます。

## 完了条件

- **E2E**
  - 条件不足のとき、メニューバー節に説明文が見える

## 経路

### 説明文が出る

- **Given**：割合の分母が取れないなど表現が制限される状態である
- **When**：設定のメニューバー節を見た時
- **Then**：説明文が見える

## 対応済みPR

- （未作成）
