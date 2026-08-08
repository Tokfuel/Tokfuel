---
id: Settings-32-about-window
title: About にバージョンとクレジットが見える
primary_domain: Settings
platforms: [macOS]
status: in-progress
---

## シナリオ

About ウィンドウにバージョン、作者、retok や Frankfurter などのクレジットが見えます。

## 完了条件

- **E2E**
  - About にバージョンが見える
  - クレジット表記が見える
- **VRT**
  - About ウィンドウが、プレビュー用フィクスチャとして固定されている

## 経路

### バージョンとクレジットが見える

- **Given**：About ウィンドウが開いている
- **When**：内容を読んだ時
- **Then**：バージョンとクレジットが見える

## 対応済みPR

- [#159](https://github.com/Tokfuel/Tokfuel/pull/159) Point-Free VRT（設定フラグ画面パターンのフィクスチャ固定）
