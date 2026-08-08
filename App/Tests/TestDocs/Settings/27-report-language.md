---
id: Settings-27-report-language
title: レポート言語を切り替えられる
primary_domain: Settings
platforms: [macOS]
status: done
---

## シナリオ

レポート言語を自動、English、日本語から選ぶと、節約のヒントなどの言語が追従します。

## 完了条件

- **E2E**
  - レポート言語を切り替えられる
  - 切替後の節約のヒントなどの言語が追従する

## 経路

### レポート言語が反映される

- **Given**：詳細が開いている
- **When**：レポート言語を日本語または English へ切り替えた時
- **Then**：節約のヒントなどの言語が追従する

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
