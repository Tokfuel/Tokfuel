---
id: Budget-17-auth-on-budget-set
title: 予算を初めて設定すると通知許可が求められる
primary_domain: Budget
platforms: [macOS]
status: done
---

## シナリオ

予算上限を初めて設定すると、通知許可のダイアログが求められます。

## 完了条件

- **E2E**
  - 予算上限を初めて設定したとき、通知許可の求めが出る

## 経路

### 通知許可が求められる

- **Given**：予算が未設定で、通知許可が未決定である
- **When**：初めて予算上限を設定した時
- **Then**：通知許可の求めが出る

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
