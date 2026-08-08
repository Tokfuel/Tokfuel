---
id: Cursor-11-degraded-warning
title: Cursor 取得劣化時に警告が出る
primary_domain: Cursor
platforms: [macOS]
status: done
---

## シナリオ

Cursor の取得が劣化しているとき、ヒーロー下に警告文と警告アイコンが出ます。

## 完了条件

- **E2E**
  - 取得劣化時、ヒーロー下に Cursor 警告が見える
- **VRT**
  - 画面 `popover-cursor-degraded` が、プレビュー用フィクスチャとして固定されている

## 経路

### 劣化警告が出る

- **Given**：Cursor 取得が劣化している
- **When**：ホームを開いた時
- **Then**：Cursor 警告が見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
