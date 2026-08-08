---
id: MenuBar-33-open-on-launch-reload
title: ホームを開いたときに集計が走って数字が新しくなる
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

ユーザーがホームを開くと集計が走り、開いた直後の数字が最新の状態になります。

## 完了条件

- **E2E**
  - ホームを開くと集計が走る
  - 開いた直後の表示が最新の集計結果である

## 経路

### 開いたときに更新される

- **Given**：Tokfuel が起動している
- **When**：ホームを開いた時
- **Then**：集計が走り、表示が最新である

## 対応済みPR

- （未作成）
