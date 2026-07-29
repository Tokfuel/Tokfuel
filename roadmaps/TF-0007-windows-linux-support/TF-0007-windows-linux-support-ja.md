[English](TF-0007-windows-linux-support.md) · **日本語**

# TF-0007 — Windows / Linux 対応

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0007](TF-0007-windows-linux-support-ja.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| Topic | プラットフォーム |
| Origin | 社内フィードバック（2026-07）: Windows / Linux のメンバーも同じ表示が欲しい |
<!-- /TF-METADATA -->

## Introduction

Claude Code が同じ `~/.claude/projects/` トランスクリプトを書き出す Windows と Linux に、
Tokfuel のコスト表示を届けます。

## Motivation

Claude Code はクロスプラットフォームですが Tokfuel はそうではありません。Windows
（WSL 含む）や Linux のメンバーもディスクに同じトランスクリプトを持ち、「今日いくら
使った？」という同じ問いを持っていますが、見る手段がありません。チーム全体でツールを
使うほど、メンバーごとのコスト可視化はむしろ重要になります。

## Detailed design

**TBD — アプローチの決定こそが本体の作業です。** 現行アプリは SwiftUI + NSStatusItem
で移植できません。候補:

1. **別実装の軽量トレイアプリ**（Rust `tray-icon` / Go `systray` / Tauri）:
   必要最小限だけ再実装する — トランスクリプト読み取り、同梱 retok（または TF-0001 の
   ネイティブ解析ロジック）の実行、今日・今月のコストと予算色をシステムトレイに表示。
   macOS アプリはそのまま。
2. **CLI ファースト**: 解析器を小さなクロスプラットフォーム CLI（`tokfuel report
   --json`）として配布し、トレイ UI（サードパーティ含む）にラップさせる。
   最小の表面積で、UI の同等性は約束しない。
3. **全面クロスプラットフォーム書き直し**（Electron/Tauri の単一コードベース、macOS
   込み）— 既定で不採用: 対称性のために動いているネイティブアプリを捨てることになります。

どの道でも共通の制約:

- トランスクリプトの場所: `~/.claude/projects/`（Linux）、
  `%USERPROFILE%\.claude\projects\` と WSL パス（Windows）— スキャン場所は設定可能のまま。
- retok は現状 python3 が必要。[TF-0001](../TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis-ja.md)（ネイティブ解析）が自然な前提または
  相棒になります。さもないと Windows での依存関係はさらに悪化します。
- ローカルファーストの原則は同一に適用します。

## Alternatives considered

- **何もしない** — Mac 以外のメンバーはターミナルで retok を手実行するしかなく、
  それこそ Tokfuel が無くそうとしている摩擦です。

## Progress

- [ ] アプローチ決定（スパイク: Windows + Linux で実トランスクリプトを読むトレイアプリの骨格）
- [ ] 非 Mac での解析手段（TF-0001 または可搬な同等物に依存）
- [ ] 配布（winget / scoop、deb/rpm または AppImage）— 現実味が出たら別項目に分割

## References

- フィードバックスレッド（社内、2026-07）
