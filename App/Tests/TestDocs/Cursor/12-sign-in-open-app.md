---
id: Cursor-12-sign-in-open-app
title: サインアウト劣化時に Cursor を開ける
primary_domain: Cursor
platforms: [macOS]
status: ready
---

## シナリオ

サインアウト相当の劣化のとき、「Cursor を開く」で Cursor アプリを前面に出せます。

## 完了条件

- **E2E**
  - サインアウト劣化時、Cursor を開く操作が見える
  - 操作すると Cursor アプリが前面に出る
- **VRT**
  - Cursor サインイン切れ時のホームが、プレビュー用フィクスチャとして固定されている

## 経路

### Cursor を開ける

- **Given**：サインアウト相当で Cursor が劣化している
- **When**：Cursor を開くを選んだ時
- **Then**：Cursor アプリが前面に出る

## 対応済みPR

- （未作成）
