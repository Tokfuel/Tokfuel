---
id: Settings-34-analytics-consent-deny
title: 同意ダイアログで許可しないを選べる
primary_domain: Settings
platforms: [macOS]
status: ready
issue:
---

## シナリオ

同意ダイアログで「許可しない」を選ぶとダイアログが閉じ、送信設定はオフのままになります。

## 完了条件

- **E2E**
  - 許可しないを選ぶとダイアログが閉じる
  - 送信設定がオフのままである

## 経路

### 許可しないで閉じる

- **Given**：同意ダイアログが出ている
- **When**：許可しないを選んだ時
- **Then**：ダイアログが閉じ、送信設定がオフである

## 対応済みPR

- （未作成）
