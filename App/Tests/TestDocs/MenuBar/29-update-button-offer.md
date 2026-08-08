---
id: MenuBar-29-update-button-offer
title: 新バージョン検出時にアップデートボタンが出る
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

新しいバージョンが検出されると、ホームのフッターにアップデートボタンが表示されます。

## 完了条件

- **E2E**
  - 新バージョン検出時、フッターにアップデートボタンが見える
- **VRT**
  - 画面 `popover-update` が、プレビュー用フィクスチャとして固定されている

## 経路

### アップデートボタンが出る

- **Given**：新バージョンが検出されているフィクスチャがある
- **When**：ホームを開いた時
- **Then**：フッターにアップデートボタンが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
