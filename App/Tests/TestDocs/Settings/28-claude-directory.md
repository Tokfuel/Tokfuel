---
id: Settings-28-claude-directory
title: Claude ディレクトリを変更しデフォルトに戻せる
primary_domain: Settings
platforms: [macOS]
status: ready
---

## シナリオ

Claude ディレクトリを変更で選べ、デフォルトで戻せます。

## 完了条件

- **E2E**
  - Claude ディレクトリを変更できる
  - デフォルトで元の場所に戻せる

## 経路

### ディレクトリを変更できる

- **Given**：詳細が開いている
- **When**：Claude ディレクトリを変更した時
- **Then**：Settings に選んだパスが入る

### デフォルトに戻せる

- **Given**：Claude ディレクトリが変更済みである
- **When**：デフォルトを選んだ時
- **Then**：Settings のパスがデフォルトに戻る

## 対応済みPR

- （未作成）
