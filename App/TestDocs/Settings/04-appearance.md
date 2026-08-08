---
id: Settings-04-appearance
title: 外観の切替が各ウィンドウに反映される
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

外観をシステム、ライト、ダークのあいだで切り替えると、ホームと設定と About の見え方が追従します。

## 完了条件

- **E2E**
  - 外観を切り替えると、ホームと設定の見え方が追従する

## 経路

### 外観が反映される

- **Given**：設定が開いている
- **When**：外観をライトまたはダークへ切り替えた時
- **Then**：開いているウィンドウの外観が追従する

## 対応済みPR

- （未作成）
