---
id: Settings-01-open
title: ポップオーバーから設定を開ける
primary_domain: Settings
platforms: [macOS]
status: in-progress
---

## シナリオ

ユーザーがホームのメニューから「設定」を選ぶと、Tokfuel 設定のウィンドウが開きます。

観測するのは、設定ウィンドウが開いてタイトルが読めることまでです。各トグルの反映は `Settings-02-reflect` で扱います。

## 完了条件

- **E2E**
  - ホームから設定を開ける
  - 開いたウィンドウが Tokfuel 設定である
- **VRT**
  - 設定ウィンドウの既定状態が、プレビュー用フィクスチャとして固定されている

## 経路

### ホームのメニューから設定を開く

- **Given**：ホーム（ポップオーバー）が開いている
- **When**：メニューから設定を選んだ時
- **Then**：Tokfuel 設定のウィンドウが表示される

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
