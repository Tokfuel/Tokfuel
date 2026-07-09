[English](CU-0004-zero-setup-transcript-scanning.md) · **日本語**

# CU-0004 — セットアップ不要のトランスクリプト走査

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0004](CU-0004-zero-setup-transcript-scanning-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **実装済み** |
| トピック | データパイプライン |
| 実装 PR | —（ローカルで実装） |
| 由来 | バックフィル（ロードマップ導入前に実装済み） |
<!-- /CU-METADATA -->

## はじめに

フックが生成する `~/.claude/usage/` の JSON を廃止し、Claude Code 自身が `~/.claude/projects/`
に書くトランスクリプトを直接読むネイティブスキャナに置き換えます。これにより、アプリはインス
トールした瞬間から動きます。フックも設定も要りません。

## 動機

元のデータソースは、ユーザーが自作した Claude Code フックが生成するリポジトリ別 JSON でした。
そのフックを持たない人がアプリを入れても、空のポップオーバーが見えるだけです。Claude Code が
常に書いているトランスクリプトには、アプリに必要なもの（tool_use ブロック、プロンプト、タイム
スタンプ、cwd）がすべて含まれているので、それを直接読めばセットアップの負担ごと消せます。これが
「入れるだけで動く」というこのアプリの土台です。

## 詳細設計

`TranscriptScanner` が `<claude-dir>/projects/**/*.jsonl` を走査し、（プロジェクト × 日）単位で
集計します。

- **行の前ふるい。** `"tool_use"` を含む行（またはツール結果でないユーザープロンプト行）だけを
  JSON デコードするので、数百 MB のツリーでも初回およそ 1.5 秒で解析できます。
- **数える対象。** `Skill` 呼び出し（`input.skill`。プラグイン接頭辞は正規化）、`mcp__*` ツール、
  `Agent`/`Task` サブエージェント（`subagent_type` 別）、人間のプロンプト（サイドチェーンでない
  ユーザー行）。
- **プロジェクトの同定**はレコードの `cwd` から行い（ghq 形式のパスなら `org/repo`）、だめなら
  トランスクリプトのディレクトリ名にフォールバックします。
- **増分キャッシュ。**（パス、mtime、サイズ）をキーにしたファイル別サマリを
  `~/Library/Application Support/ClaudeUsageMenubar/transcript-cache.json` に永続化します。変化の
  ないファイルは二度と読み直さず、消えたファイルのエントリは破棄します。
- 出力は既存の `RepoUsage` の形なので、集計層と UI 層は無変更で済みました。

## 検討した代替案

**フックベースの `~/.claude/usage/` を維持する。** 不採用。全ユーザーにまずフックを書かせること
になり、「チラ見できること」が価値のアプリと矛盾します。

**全行を JSON としてパースする。** 不採用。273 MB のツリーで一桁遅くなるのに、得られる情報は
増えません。マーカーの前ふるいでも同じレコードを読めます。

## 進捗

- [x] `TranscriptScanner`（前ふるい、日次集計、プロジェクト同定）。
- [x] 無効化つきのファイル別増分キャッシュ。
- [x] `~/.claude/usage/` ローダの撤去。走査ルートは設定可能（[CU-0005](../CU-0005-settings-window/CU-0005-settings-window-ja.md) 参照）。

## 参考

- `ClaudeUsageMenubar/Sources/TranscriptScanner.swift`
- `ClaudeUsageMenubar/Sources/UsageStore.swift`（`reload`、集計）
- [CU-0003](../CU-0003-retok-cost-tab/CU-0003-retok-cost-tab-ja.md) — retok も同じトランスクリプトからコストを読む。
</content>
