---
id: Cursor-13-recheck-after-sign-in
title: サインイン後にホームを開き直すと再取得する
primary_domain: Cursor
platforms: [macOS]
status: ready
---

## シナリオ

サインインしたあとホームを開き直すと、Cursor の再取得が走ります。

## 完了条件

- **E2E**
  - サインイン後にホームを開き直すと、Cursor の再取得が走る

## 経路

### 再取得が走る

- **Given**：以前は劣化していて、その後 Cursor にサインインした
- **When**：ホームを開き直した時
- **Then**：再取得が走り、劣化表示が解消へ向かう

## 対応済みPR

- （未作成）
