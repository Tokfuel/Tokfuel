[English](CU-0007-server-quota-readout.md) · **日本語**

# CU-0007 — サーバー真値クォータ表示（オプトイン）

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0007](CU-0007-server-quota-readout-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **実装済み** |
| トピック | 使用量とクォータ |
| 実装 PR | —（ローカルで実装） |
<!-- /CU-METADATA -->

## はじめに

Claude Code がローカルに保存している OAuth 認証情報を読み、Anthropic の使用量エンドポイント
に問い合わせて、プランのクォータ消費率（5 時間ウィンドウ・週次・モデル別）を*サーバー側の
正確な値*で表示する**オプトイン**機能です。公式の `/usage` コマンドと同じ数字を、手動の
トークン設定なしで出します。

## 動機

ローカルのトランスクリプト集計（CU-0006）はあくまで推定です。CCSeva・Usage4Claude・Raycast
の ccusage 拡張のユーザーは一様にサーバー側クォータ%を評価しており、「`/usage` と数字が
合わない」はローカル集計ツールへの定番の不満です。Usage4Claude はセッションキーの手動貼り
付けを要求し、CCSeva は Electron 製です。Claude Code が維持している認証情報をそのまま再利用
すれば、ゼロセットアップを守ったままネイティブアプリで両者の長所を取れます。CU-0006 と
組み合わせると「オフラインでは推定、有効化すれば真値」になります。

## 詳細設計

- **デフォルトは無効。** 原則 1 は「ネットワーク送信をしない」ですが、この機能が送るのは
  ユーザー自身の既存 OAuth トークンだけで、宛先も Anthropic の API のみです（使用データや
  サードパーティへの送信はありません）。設定のトグルにこの旨を明記し、無効のままでもアプリ
  の他機能はすべて動きます。
- **認証情報の取得元**: Claude Code が保存する OAuth 認証情報（Keychain、環境によっては
  `~/.claude/.credentials.json`）。読み取り専用とし、Claude Code 自身のトークン更新処理と
  競合する書き込みは行いません。トークンが失効・不在のときは「Claude Code を開くと更新
  されます」と案内し、CU-0006 の推定値にフォールバックします。
- **エンドポイント**: 公式クライアントが使う使用量 / レートリミットのエンドポイント
  （CCSeva や Raycast 拡張と同じ）。アプリの既存の更新間隔でポーリングし、エラー時は
  バックオフします。
- **UI**: Session ビュー（CU-0006）でサーバー値を主、ローカル推定を従として表示します。
  メニューバー表示と通知も、サーバー値が取れるときはそちらに切り替えます。
- **プライバシー注記**: 送るもの（トークンのみ・宛先は Anthropic のみ）と決して送らないもの
  （トランスクリプト・コストなど）を README（両言語）に明記します。

## 検討した代替案

**セッションキーの手動入力（Usage4Claude 方式）。** 不採用。ゼロセットアップが崩れるうえ、
キーの失効のたびに手間が発生します。

**完全ローカルのままにする。** それがこの機能のデフォルト状態です。推定と真値のずれが
ローカル集計ツールへの最大の不満であるため、原則を守りたい人には無効のまま、正確さが欲しい
人にはオプトインで、という切り分けにします。

**公式 OTel テレメトリ。** 不採用。Claude Code 側の設定と OTLP バックエンドが必要で、
セットアップが重く、チーム向けの仕組みです。

## 進捗

- [x] Spike（CodexBar のソース調査による。MIT © Peter Steinberger）: エンドポイントは
  `GET https://api.anthropic.com/api/oauth/usage`（`Authorization: Bearer` と
  `anthropic-beta: oauth-2025-04-20`）。応答は `five_hour` / `seven_day` /
  `seven_day_opus` の `{utilization, resets_at}`。認証情報は
  `~/.claude/.credentials.json`（`claudeAiOauth.accessToken`）または Keychain の
  `"Claude Code-credentials"`。トークンの更新は行いません（ローテーション競合のため。
  CodexBar も同じ理由で CLI に委譲しています）。
- [x] `ClaudeQuotaService`（認証情報の検出: ファイル → Keychain、取得、デコード）と
  ユニットテスト（`tests/ClaudeQuotaTests.swift`）。
- [x] 設定トグル（既定 OFF）。「何を送るか」を明記したフッター付き。
- [x] Cost タブ先頭の「Limits」セクション: 5h / 7d / 7d-Opus のバーとリセットまでの時間。
- [x] `~/.claude.json` の `oauthAccount.userRateLimitTier` によるローカルのプランバッジ
  （ネットワーク不要。CU-0010 のプラン検出の先行実装でもあります）。
- [ ] 後続: メニューバー・通知のサーバー値への切り替え（CU-0006 の Session ビュー側）、
  アプリの更新間隔を超えるポーリングバックオフ。

## 参考

- [CU-0006](../CU-0006-session-block-tracking/CU-0006-session-block-tracking-ja.md) — この機能が補強するローカル推定。
- [CCSeva](https://github.com/Iamshankhadeep/ccseva)、[Usage4Claude](https://github.com/f-is-h/Usage4Claude)、[Raycast ccusage 拡張](https://www.raycast.com/nyatinte/ccusage) — サーバー真値表示の先行事例。
- `CLAUDE.md` 原則 1（ローカル限定）— この項目がオプトインで慎重に扱う境界。
