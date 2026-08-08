# TestDocs（テストシナリオ）

作業規範は [`AGENTS.md`](AGENTS.md) を参照してください。担保手段は [`coverage-strategy.md`](coverage-strategy.md) です。

Tokfuel アプリのテスト観点を git 上の Markdown として管理します。  
メニューバーアプリ向けに、ドメイン直下の連番とスラッグで観点を置きます。

1. **起票**: 壁打ちし、OK 後にシナリオ MD を追加する（プロダクトコードは触らない）
2. **実装**: シナリオ MD を正本に E2E（必要なら UT / IT / VRT）を書き、`status` と対応済みPR を更新する
3. **日本語**: Issue / PR / シナリオ本文は [`japanese-tech-writing`](../../.agents/skills/japanese-tech-writing/SKILL.md) に従う

## ディレクトリ規約

```text
App/TestDocs/
  README.md
  AGENTS.md
  _TEMPLATE.md
  coverage-strategy.md
  CATALOG.md
  MenuBar/
  Cost/
  Settings/
  Budget/
  Cursor/
```

- パス: `App/TestDocs/{Domain}/{nn}-{slug}.md`
- 観点 ID: `{Domain}-{nn}-{slug}`（例: `Cost-02-period-switch`）
- 1 ファイル = 1 シナリオ（観点 ID）
- front matter: `id` / `title` / `primary_domain` / `platforms` / `status`。`issue` は関連 GitHub Issue があるときだけ（無いときは行ごと省略）
- `platforms` は `[macOS]` 固定（本文に `## 対象` は書かない）
- 節の順は **シナリオ → 完了条件 → 経路 → 対応済みPR**（[`_TEMPLATE.md`](_TEMPLATE.md)）
- **完了条件**は手段ごとのステップ箇条書き。原則は **E2E**。UT&IT と VRT は補助
- **経路**は実装するテスト単位。見出しは振る舞いのみ（クラス名禁止）。その下に GWT
- Then は Store / Settings / 表示状態を主検証とする

### primary_domain の目安

| domain | 扱うもの |
| --- | --- |
| `Budget` | 予算バー、しきい値、通知 |
| `Cost` | コスト集計、モデル別、セッション、推移グラフ |
| `Cursor` | Cursor 従量 / included 枠 / サインイン状態 |
| `Settings` | 設定画面、表示モード、通貨 |
| `MenuBar` | メニューバー表示とホーム（ポップオーバー）の開き方 |

## front matter の status

| Status | 意味 |
| --- | --- |
| `ideation` | 壁打ち中。GWT がまだ実装に足りない |
| `ready` | 実装着手可 |
| `in-progress` | 実装ブランチ作業中 |
| `review` | PR レビュー中（任意） |
| `done` | 実装完了。テスト通過後、マージ前の実装 PR で更新してよい |

<!-- testdocs-coverage:start -->
## カバレッジ

主指標の **実装カバレッジ** はいま **0.0%**（`0/131`）です。着手カバレッジは 0.0%（`0/131`）、起票完了率は 100.0%（`131/131`）、E2E 完了条件の記載率は 100.0%（`131/131`）です。

定義とドメイン別内訳は [`CATALOG.md`](CATALOG.md) の「カバレッジ」節、機械可読な値は [`coverage.json`](coverage.json) を見てください。

```bash
python3 Scripts/generate-testdocs-catalog.py
```

<!-- testdocs-coverage:end -->

## シナリオ索引

全件の一覧と面ごとの確認チェックは [`CATALOG.md`](CATALOG.md) を見てください（網羅確認用）。

シナリオを追加・変更したら、次で索引を再生成します。

```bash
python3 Scripts/generate-testdocs-catalog.py
```

## 実行コードの置き場

| 手段 | 置き場 |
| --- | --- |
| E2E | [`../E2E`](../E2E/) |
| UT / IT | [`../Tests`](../Tests/) |
| VRT 土台 | `ScreenshotRenderer` / `ui-preview`（自動ピクセル比較は後続） |

Site のシナリオはここに置きません。
