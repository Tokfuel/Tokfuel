[English](TF-0002-notarized-distribution.md) · **日本語**

# TF-0002 — Developer ID 署名と公証

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0002](TF-0002-notarized-distribution-ja.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| Topic | 配布 |
| Origin | v0.0.1 テスターからの Gatekeeper 警告の報告 |
<!-- /TF-METADATA -->

## Introduction

リリースを Developer ID Application 証明書で署名し公証（notarization）することで、
ダウンロードしたビルドが「Apple は検証できませんでした…」という Gatekeeper 警告なしに
起動できるようにします。

## Motivation

現在のリリースはアドホック署名です。ダウンロードした全員が Gatekeeper にブロックされ、
回避策（右クリック→開く、「このまま開く」、`xattr -d com.apple.quarantine`、curl での取得）
が必要になります。実際のテスターがすでにここでつまずいており、アプリを共有するうえで
最大の摩擦になっています。

## Detailed design

前提: Apple Developer Program への登録（年 99 米ドル）。

- **証明書とシークレット。** Developer ID Application 証明書（`.p12`）と App Store Connect
  の API キーを GitHub Actions のシークレットに保存します。
- **リリースワークフロー**（[release.yml](../../.github/workflows/release.yml)）:
  1. Developer ID で `codesign --options runtime`（公証には hardened runtime が必須）—
     `scripts/release.sh` の現行 `--sign -` を置き換えます。
  2. zip を `xcrun notarytool submit --wait` で提出します。
  3. `xcrun stapler staple` でチケットを添付し、再 zip してアップロードします。
- **ローカルのフォールバック。** 証明書なしでも `scripts/release.sh` は（アドホックで）
  動き続け、ローカルのパッケージングにシークレットを要求しません。
- **README。** 公証済みリリースが出たら Gatekeeper 回避手順の記載を削除します。

## Alternatives considered

- **現状維持（アドホック + 回避手順のドキュメント）** — 無料ですが、新規ユーザー全員が摩擦を払います。
- **Mac App Store** — python3 サブプロセスが残る限り不可（[TF-0001](../TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis-ja.md)）。
- **Homebrew cask** — インストールは楽になりますが、未署名アプリへの Gatekeeper の判定は変わりません。

## Progress

- [ ] Apple Developer Program への登録
- [ ] 証明書と API キーのシークレットをリポジトリに追加
- [ ] release.yml に署名・公証・staple のステップ（ローカルはアドホックのまま）
- [ ] README のインストール手順を更新

## References

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- Developer ID 署名＋公証スクリプトの下書きがリポジトリ直下の `release.sh` にありました（2026-07 に削除。git 履歴から復元可能）— 実装の出発点に再利用できます。
