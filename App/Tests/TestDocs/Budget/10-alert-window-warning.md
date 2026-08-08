---
id: Budget-10-alert-window-warning
title: しきい値到達をアラートウィンドウで知らせる
primary_domain: Budget
platforms: [macOS]
status: in-progress
---

## シナリオ

知らせ方がアラートウィンドウのとき、しきい値到達で警告アラートが前面に出ます。

## 完了条件

- **E2E**
  - 知らせ方がアラートウィンドウのとき、しきい値到達でアラートが見える
- **VRT**
  - 画面 `budget-alert` が、プレビュー用フィクスチャとして固定されている

## 経路

### 警告アラートが出る

- **Given**：知らせ方にアラートウィンドウが含まれ、消費がしきい値に達した直後である
- **When**：画面を見た時
- **Then**：警告アラートが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
