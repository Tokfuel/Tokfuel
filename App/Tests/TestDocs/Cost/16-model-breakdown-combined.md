---
id: Cost-16-model-breakdown-combined
title: モデル別をまとめて表示できる
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

モデル別の出し方がまとめてのとき、ソースをまたいだモデルが一覧にマージされます。

## 完了条件

- **E2E**
  - まとめてのとき、モデル別が一覧として見える
  - ソース見出しで分割されていない

## 経路

### まとめて一覧になる

- **Given**：複数ソースのモデル内訳があり、出し方がまとめてである
- **When**：モデル別を見た時
- **Then**：ソース見出しなしの一覧になっている

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
