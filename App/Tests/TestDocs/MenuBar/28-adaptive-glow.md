---
id: MenuBar-28-adaptive-glow
title: 追従中の明滅がメニューバーアイコンに出る
primary_domain: MenuBar
platforms: [macOS]
status: done
---

## シナリオ

使用中は更新を速めるがオンで、明滅もオンのとき、追従モード中はメニューバーアイコンが明滅します。

## 完了条件

- **E2E**
  - 追従中かつ明滅オンのとき、メニューバーアイコンが明滅する

## 経路

### 追従中に明滅する

- **Given**：使用中は更新を速めると明滅がオンで、利用が追従中である
- **When**：メニューバーアイコンを見た時
- **Then**：明滅している

## 対応済みPR

- [#160](https://github.com/Tokfuel/Tokfuel/pull/160) AX E2E（TestDocs 全シナリオ）

- （未作成）
