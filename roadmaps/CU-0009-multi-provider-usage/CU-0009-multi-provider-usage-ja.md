[English](CU-0009-multi-provider-usage.md) · **日本語**

# CU-0009 — マルチプロバイダ使用量比較（Codex / Gemini CLI）

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0009](CU-0009-multi-provider-usage-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **実装済み** |
| トピック | プロバイダ |
| 由来 | [steipete/CodexBar](https://github.com/steipete/CodexBar) |
| 実装 PR | —（ローカルで実装） |
<!-- /CU-METADATA -->

## はじめに

ほかの AI コーディング CLI が書き出すローカルのセッションログ — まずは OpenAI Codex CLI
（`~/.codex/`）と Gemini CLI（`~/.gemini/`）— を読み、Claude Code の使用量と並べて表示
します。複数のアシスタントを使い分けている人が、トークン・推定コスト・活動量をひとつの
ポップオーバーで比較できるようにする提案です。

## 動機

CodexBar（★約 1.8 万）が需要を証明しました。開発者はいまや複数のコーディングエージェント
を併用しており、ベンダーごとにアプリを入れるのではなく、ひとつのメニューバー計器を求めて
います。ただし CodexBar は意図的に「広く浅く」です。58 プロバイダのメーターを並べる一方、
Claude Code の読み取りは CLI を PTY で起動して `/usage` の出力をパースする方式で、出力
変更に脆く、CLI のインストールが前提です。Tokfuel の立ち位置はその逆で、Claude Code に
ついては最も深く（トランスクリプト内容の分析）、Claude 中心の開発者が実際に併用する隣人
たちには*比較用*のメーターを添えます。Codex CLI も Gemini CLI も JSONL 系のローカル
セッションログを書くため、ローカルファイルの読み取りのみ・セットアップ不要・ネットワーク
なしという本アプリの原則にそのまま収まります。

## 詳細設計

- **プロバイダ抽象**: `UsageProvider` プロトコル（ID・表示名・ログの場所・走査 → 日別の
  トークン / コスト / セッション）を導入し、既存の Claude パイプラインを最初の実装とします。
  ログディレクトリが存在しないプロバイダは、単に表示されません。
- **Codex CLI リーダー**: `~/.codex/sessions/`（JSONL のロールアウトファイル）から
  タイムスタンプ・モデル・トークン使用イベントをパースします。
- **Gemini CLI リーダー**: `~/.gemini/tmp/<hash>/` のセッションログ / テレメトリファイル
  をパースします。
- **コスト推定**: プロバイダ・モデル別の静的な価格表で見積もります（[CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md)
  のネイティブ価格計算と同じ仕組み。更新可能な JSON として同梱）。
- **UI**: 「Providers」比較セクションを追加します。検出されたプロバイダごとに 1 行で、
  今日 / 7 日 / 30 日のトークンと推定コスト、全体に占める割合のバー、最終活動時刻を示し
  ます。Claude は従来どおり詳細画面が主役で、他プロバイダは v1 ではサマリーまでとします。
- **設定**: プロバイダごとの ON/OFF と追加スキャンパス（CU-0005 の方式を踏襲）。
- **スコープの歯止め**: 他ベンダーへの OAuth・Cookie 読み取り・PTY 起動・サーバー問い
  合わせは行いません。ローカルログのないプロバイダは対象外です（そこは CodexBar の土俵
  であり、本アプリの戦場ではありません）。

## 検討した代替案

**CodexBar と同じ 50+ プロバイダ対応。** 不採用。広さを取ると認証フロー・Cookie 読み取り・
スクレイピングが必要になり、ローカル限定とゼロセットアップの原則に反するうえ、小さな
アプリでは維持できません。ローカルログを丁寧に読める 2〜3 プロバイダで、Claude ファースト
なユーザーの実際の併用範囲はカバーできます。

**各 CLI の usage コマンドを PTY で叩く（CodexBar の Claude 方式）。** 不採用。CLI の出力
変更に脆く、バイナリの存在が前提になります。ログファイルのほうが安定した契約です。

## 進捗

- [x] Codex リーダー（`CodexUsageReader`）: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`
  から日別のセッション数と入出力トークンを集計します（各セッションの最後の
  `total_token_usage` 行 = 累積値を採用。`info: null` の行は無視）。実データと同形の
  フィクスチャによるユニットテスト（`tests/CodexUsageReaderTests.swift`）に加え、
  実機の 40 セッションで検証済みです。
- [x] Tools タブの「Providers」セクション（Codex のログがあるときだけ表示）。プロバイダ
  共通の単位はセッション数（シェアバー）で、詳細は Claude がプロンプト数、Codex が
  トークン数。最終活動日を添え、CU-0011 の期間フィルタに追従します。
- [x] **Gemini リーダーは根拠付きで見送り**: ローカルの Gemini CLI チャットログ
  （`~/.gemini/tmp/*/chats/session-*.json`）にはトークン使用量のフィールドが一切なく、
  集計できるものがありません。Gemini CLI がローカルに使用量を書くようになったら再検討します。
- [ ] 後続に回したもの: プロバイダ別の設定・追加スキャンパス（CU-0005 方式）、Codex の
  コスト換算（CU-0002 の共通価格 JSON が前提。推測価格は出さない）、`UsageProvider`
  プロトコルの本格導入（追加プロバイダが 1 つの段階では時期尚早）。

## 参考

- [steipete/CodexBar](https://github.com/steipete/CodexBar) — 由来であり先行事例（広さ優先の設計）。
- `Tokfuel/Sources/TranscriptScanner.swift`、`UsageStore.swift` — 一般化する Claude パイプライン。
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) — 流用するネイティブ価格表。
- [CU-0010](../CU-0010-plan-and-unit-cost/CU-0010-plan-and-unit-cost-ja.md) — 比較を補完するプラン・単価表示。
