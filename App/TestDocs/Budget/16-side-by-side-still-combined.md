---
id: Budget-16-side-by-side-still-combined
title: 並べて表示でも予算の分母は合算のまま
primary_domain: Budget
platforms: [macOS]
status: ready
issue:
---

## シナリオ

コストのソースが並べて表示でも、予算ゲージの分母は合算コストのままです。

## 完了条件

- **E2E**
  - 並べて表示でも、予算メーターの分母が合算である
- **UT&IT**
  - 予算判定の対象コストが合算である

## 経路

### 予算は合算のまま

- **Given**：並べて表示で、予算上限がある
- **When**：ホームの予算メーターを見た時
- **Then**：分母が合算コストになっている

## 対応済みPR

- （未作成）
