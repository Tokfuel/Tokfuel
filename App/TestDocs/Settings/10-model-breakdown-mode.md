---
id: Settings-10-model-breakdown-mode
title: モデル別の出し方を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

設定のモデル別の出し方を、まとめてとソース別に分けるのあいだで切り替えられます。

## 完了条件

- **E2E**
  - モデル別の出し方をまとめてとソース別に切り替えられる
  - 切替後のホームのモデル別が選んだ出し方に追従する

## 経路

### 出し方を切り替えられる

- **Given**：設定が開いている
- **When**：モデル別の出し方を切り替えた時
- **Then**：Settings の値が変わり、ホームのモデル別が追従する

## 対応済みPR

- （未作成）
