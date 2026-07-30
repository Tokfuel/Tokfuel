# Vendored: retok

このディレクトリの `retok.py` と `locales/` は、Daiki Matsudate (@d-date) 氏の著作物
**retok** の無改変コピーです（`retok.py` はファイル名のみ `retok` から変更）。

- Upstream: https://github.com/d-date/retok
- Author: Daiki Matsudate (@d-date)
- License: MIT License — 全文は同ディレクトリの `LICENSE-retok` を参照
- Vendored commit: `9ef302f3fa64c162515d6687a5ba104f9e393feb` (2026-07-06)

## 更新手順

上流の変更（モデル価格表の更新など）を取り込むときは、改変せずにコピーし直し、
このファイルのコミットハッシュを更新すること:

```sh
cp <retok>/retok    Tokfuel/Sources/Resources/retok.py
cp -R <retok>/locales Tokfuel/Sources/Resources/locales
cp <retok>/LICENSE  Tokfuel/Sources/Resources/LICENSE-retok
```

ローカルで改変しないこと（改変が必要になったら上流に PR を出す）。
