---
id: Settings-18-adaptive-refresh
title: 使用中は更新を速めるを切り替えられる
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

「使用中は更新を速める」を切り替えると、利用中の更新間隔の挙動が変わります。

## 完了条件

- **E2E**
  - 使用中は更新を速めるを切り替えられる
- **UT&IT**
  - 追従更新フラグが更新間隔の選択に使われる

## 経路

### 追従更新を切り替えられる

- **Given**：設定のメニューバー節が開いている
- **When**：使用中は更新を速めるを切り替えた時
- **Then**：Settings の値がトグルに追従する

## 対応済みPR

- （未作成）
