[English](README.md) · **日本語**

# Tokfuel — ロードマップ / バックログ

このディレクトリは、計画中・進行中・実装済みの機能を管理します。各項目はディレクトリ
`CU-NNNN-<slug>/` で、英語ファイル `CU-NNNN-<slug>.md` と日本語ミラー
`CU-NNNN-<slug>-ja.md`（同じ ID と slug）を持ちます。**CU** は旧アプリ名 *Claude Usage* の略（ID の安定のため据え置き）で、`NNNN`
は 4 桁ゼロ埋めの単調増加 ID です。

この規約は [bajutsu-e2e/bajutsu](https://github.com/bajutsu-e2e/bajutsu) のロードマップ体系
（`BE` プレフィックス）を参考に、小規模な単一アプリのリポジトリ向けに簡素化したものです。ID
は手動採番で、この索引も手動更新します（CI 生成やゲートはありません）。

## 凡例

**状態** — 💡 Proposal（提案）/ 🚧 In progress（進行中）/ ✅ Implemented（実装済み）/ ❄️ Deferred（保留）

## 項目の追加手順

1. **次の ID を採番** = 既存の最大 `CU-NNNN` + 1:
   ```bash
   ls -d roadmaps/CU-*/ | sort | tail -1
   ```
   ID は不変です。状態が変わっても、実装されても、決して振り直しません。
2. **ディレクトリと両言語ファイルを作成**
   `roadmaps/CU-NNNN-<slug>/CU-NNNN-<slug>.md`（英語）と `...-ja.md`（日本語、同じ ID と slug）。
   各ファイルは **Swift-Evolution 提案形式**に従います。メタデータブロックのあと、
   `## Introduction` / `## Motivation` / `## Detailed design` / `## Alternatives considered` /
   `## Progress` / `## References`（書ける範囲で埋め、不明点は `TBD`）。
3. **メタデータ**は `<!-- CU-METADATA -->` 〜 `<!-- /CU-METADATA -->` の `| 項目 | 値 |` 表で、
   `提案` / `提案者`（GitHub ハンドル）/ `状態` / `トピック`（実装後は `実装 PR`、該当時は `由来`）
   を持ちます。英語ミラーは `Proposal` / `Author` / `Status` / `Topic` / `Implementing PR` / `Origin`。
4. 項目を追加・昇格したら、下の表を手動で更新します。

日本語ファイル（`*-ja.md`）は [`japanese-tech-writing`](../.claude/skills/japanese-tech-writing/SKILL.md)
スキルに従って **敬体（ですます調）**で書きます。英語の逐語訳ではなく、自然な日本語にします。

ロードマップの運用は [`.claude/skills/`](../.claude/skills/) 配下のスキルが担います。
[`ideation`](../.claude/skills/ideation/SKILL.md)（提案を書く）、
[`implement-cu`](../.claude/skills/implement-cu/SKILL.md)（採番済み項目を実装する）、
[`propose-and-build`](../.claude/skills/propose-and-build/SKILL.md)（両方）、
[`roadmap-filter`](../.claude/skills/roadmap-filter/SKILL.md)（状態で一覧）、
[`task-select`](../.claude/skills/task-select/SKILL.md)（次の項目を選ぶ）。

---

## ✅ Implemented（実装済み）

| ID | 項目 | トピック |
|---|---|---|
| [CU-0001](CU-0001-budget-alerts/CU-0001-budget-alerts-ja.md) | 予算アラート（メニューバー色 + 通知） | コストと予算 |
| [CU-0003](CU-0003-retok-cost-tab/CU-0003-retok-cost-tab-ja.md) | retok によるコストタブ | コストと予算 |
| [CU-0004](CU-0004-zero-setup-transcript-scanning/CU-0004-zero-setup-transcript-scanning-ja.md) | セットアップ不要のトランスクリプト走査 | データパイプライン |
| [CU-0005](CU-0005-settings-window/CU-0005-settings-window-ja.md) | 設定ウィンドウとスキャン場所の設定 | 設定と UX |

## 💡 Proposals（提案）

| ID | 項目 | トピック |
|---|---|---|
| [CU-0002](CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) | コスト分析の Swift ネイティブ再実装（python3 依存の廃止） | コストと予算 |
| [CU-0006](CU-0006-session-block-tracking/CU-0006-session-block-tracking-ja.md) | 5 時間セッションブロックの追跡（バーンレートと到達予測つき） | 使用量とクォータ |
| [CU-0007](CU-0007-server-quota-readout/CU-0007-server-quota-readout-ja.md) | サーバー真値クォータ表示（オプトイン） | 使用量とクォータ |
| [CU-0008](CU-0008-project-cost-breakdown/CU-0008-project-cost-breakdown-ja.md) | プロジェクト別のコスト・アクティビティ内訳 | コストと予算 |
| [CU-0009](CU-0009-multi-provider-usage/CU-0009-multi-provider-usage-ja.md) | マルチプロバイダ使用量比較（Codex / Gemini CLI） | プロバイダ |
| [CU-0010](CU-0010-plan-and-unit-cost/CU-0010-plan-and-unit-cost-ja.md) | プラン情報とトークン単価の表示 | コストと予算 |
| [CU-0011](CU-0011-today-usage/CU-0011-today-usage-ja.md) | 「今日」の使用量表示 | 設定と UX |
| [CU-0012](CU-0012-unused-skills-audit/CU-0012-unused-skills-audit-ja.md) | 指定リポジトリルート配下の未使用スキル調査 | スキルとツール |

## 🚧 In progress（進行中）

_まだありません。_

## ❄️ Deferred（保留）

_まだありません。_

## 未整理のアイデア

まだ項目に落とし込めていない着想です。スコープが固まったら採番して項目に昇格します。

- 編集メトリクス（追加 / 削除行数）の可視化。データはすでにデコード済み。
- 署名・公証済みリリースビルドの自動化（[`release.sh`](../release.sh) 参照）。
</content>
