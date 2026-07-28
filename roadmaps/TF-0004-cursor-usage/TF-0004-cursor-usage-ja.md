[English](TF-0004-cursor-usage.md) · **日本語**

# TF-0004 — Cursor の利用データ収集

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0004](TF-0004-cursor-usage-ja.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| Topic | プロバイダ |
| Origin | 社内テスターのフィードバック（2026-07）:「Cursor の利用データも収集したい」 |
<!-- /TF-METADATA -->

## Introduction

Cursor の AI 利用量（算出できるならコストも）を Claude Code と並べて表示し、両方の
ツールを使い分けている人が合計を 1 つの数字で見られるようにします。

## Motivation

テスターの何人かはエディタとして Cursor を主に使い、エージェント作業に Claude Code を
使っています。現在の Tokfuel が答えるのは「Claude Code にいくらかかったか」だけで、
そうしたユーザーにとっては請求の半分にすぎません。

## Detailed design

**TBD — まず調査スパイクが必要です。** 未解決の問いを順に:

1. **Cursor はローカルに何を残すか？** 候補: `~/Library/Application Support/Cursor/`
   （SQLite の `state.vscdb`、ログ）。リクエスト数・モデル名・トークン使用量が
   ディスクから復元できるかを確認します。
2. **ローカルデータで足りない場合**、（Cursor のダッシュボードが使うような）認証付き
   利用量 API はあるか？ あるなら、削除したサーバークォータ機能と同じ構造の
   オプトイン通信（トークンのみ・ベンダーのみ）として設計します。
3. **見せ方。** ポップオーバーにプロバイダ別セクションを追加。ヒーローは合計
   （または Claude のみ）— データの形が分かってから決めます。

原則: ローカルファイルの読み取りは常に可。ネットワーク取得は必ず独立したオプトインで、
利用データを外に送らないこと。

## Alternatives considered

- **何もしない** — Tokfuel は Claude 専用の単機能のまま。Cursor がローカルに有用な
  データを残していなければ、これが帰結になります。

## Progress

- [ ] スパイク: Application Support 配下に Cursor が保存する内容の棚卸し（以降のブロッカー）
- [ ] ローカルのみ / オプトイン API の判断
- [ ] リーダーとポップオーバーのセクション
- [ ] 予算に含めるか？（スパイク後に判断）

## References

- フィードバックスレッド（社内、2026-07-28）
