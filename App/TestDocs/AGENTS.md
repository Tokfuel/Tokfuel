# AGENTS.md — TestDocs 作業規範

> `App/TestDocs/` 配下を触るセッションの共有前提。リポジトリ全体の前提は [`../../AGENTS.md`](../../AGENTS.md)。

## これは何か

**TestDocs** は、Tokfuel アプリのテスト観点シナリオを git 上の Markdown で管理する置き場である。  
成果物は `App/TestDocs/{Domain}/**/*.md` とする。壁打ちで MD を起票し、実装 PR でテストとステータス更新まで進める。

## 破ってはいけないこと

1. **1 ファイル = 1 観点 ID。** パスと front matter の `id` を一致させる。
2. **観点 ID / GWT / 判定結果を捏造しない。** 既存 MD・コード・Issue に接地する。根拠が無いときはユーザーに確認する。
3. **シナリオ起票中はプロダクトコードとテストコードを触らない。** `App/Tokfuel/` / `App/Tests/` / `App/E2E/` の変更は実装レーンの役割である。
4. **実装の正はビルド / テストである。** テスト未通過のまま `status` を `done` にしない。通過後はマージ前の実装 PR で `done` にしてよい。
5. **グラウンドルールを守る。** ローカルオンリー、ゼロセットアップ、新規パッケージ禁止はリポジトリ全体の AGENTS に従う。

## 担保手段の優先

詳細は [`coverage-strategy.md`](coverage-strategy.md)。

- 完了条件: **E2E** を主とする。UT&IT と VRT は補助
- 同じ観測を手段のあいだで二重にテストしない

## 完了判定

| レーン | 完了の正 |
| --- | --- |
| 起票 | [`_TEMPLATE.md`](_TEMPLATE.md) の必須項目が揃い、`status` が `ready` になり、ユーザー合意のうえで起票 PR（または実装と同じ PR）に載せたこと |
| 実装 | 対象テストが通り、同じ PR で MD の「対応済みPR」と `status: done` を更新したこと（マージ前でよい） |

## 規約（要約）

- パス: `App/TestDocs/{Domain}/{nn}-{slug}.md`
- 観点 ID: `{Domain}-{nn}-{slug}`（例: `Cost-02-period-switch`）
- Domain は `primary_domain` と一致（`MenuBar` / `Cost` / `Settings` / `Budget` / `Cursor`）
- `nn` はドメイン内 2 桁連番。`slug` は英小文字ハイフンでファイル名末尾と一致
- 雛形: [`_TEMPLATE.md`](_TEMPLATE.md) / 入口: [`README.md`](README.md) / 網羅確認: [`CATALOG.md`](CATALOG.md)
- カバレッジ: `python3 Scripts/generate-testdocs-catalog.py` が [`CATALOG.md`](CATALOG.md) / [`coverage.json`](coverage.json) / README のカバレッジ節を更新する。主指標は実装カバレッジ（`status: done` / 全件）
- 節順: **シナリオ → 完了条件 → 経路（テスト単位 GWT）→ 対応済みPR**
- `platforms` は front matter。本文に `## 対象` / 「前提条件」節は書かない
- 経路見出しは振る舞いのみ（クラス名禁止）
- Then は Store / Settings / 表示状態を主とし、HTTP 回数などは補助
- シナリオ MD の地の文は敬体（ですます調）。本ファイルのような作業規範は常体でよい
- ブランチはリポジトリ規約どおり `claude/<short-topic>`（TestDocs 専用 trunk は設けない）
