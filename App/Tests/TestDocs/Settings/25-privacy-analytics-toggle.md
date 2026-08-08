---
id: Settings-25-privacy-analytics-toggle
title: 利用状況の送信許可を後から切り替えられる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

プライバシーの「利用状況の送信を許可」を後からオンオフできます。

## 完了条件

- **E2E**
  - 利用状況の送信を許可を切り替えられる

## 経路

### 送信許可を切り替えられる

- **Given**：設定のプライバシー節が開いている
- **When**：利用状況の送信を許可を切り替えた時
- **Then**：Settings の値がトグルに追従する

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
