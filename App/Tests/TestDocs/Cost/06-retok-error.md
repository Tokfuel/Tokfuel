---
id: Cost-06-retok-error
title: retok 失敗時にエラー文が出る
primary_domain: Cost
platforms: [macOS]
status: done
---

## シナリオ

python3 が無いなど retok が失敗すると、ホームに警告ラベルでエラー文が出ます。設定やメニューバー自体は動き続けます。

## 完了条件

- **E2E**
  - retok 失敗時、ホームにエラー文が見える
  - 失敗しても設定やメニューバーは操作できる

## 経路

### エラー文が見える

- **Given**：retok が失敗する状態である
- **When**：ホームを開いた時
- **Then**：エラー文が見え、設定は開ける

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
