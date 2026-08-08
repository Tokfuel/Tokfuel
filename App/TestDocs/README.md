# TestDocs（テストシナリオ）

作業規範は [`AGENTS.md`](AGENTS.md) を参照してください。担保手段は [`coverage-strategy.md`](coverage-strategy.md) です。

Tokfuel アプリのテスト観点を git 上の Markdown として管理します。  
Sansan の testDoc 運用を参考にしつつ、macOS メニューバーアプリ向けに簡素化しています。

1. **起票** — 壁打ちし、OK 後にシナリオ MD を追加する（プロダクトコードは触らない）
2. **実装** — シナリオ MD を正本に UT / IT / VRT（必要なら E2E）を書き、`status` と対応済みPR を更新する
3. **日本語** — Issue / PR / シナリオ本文は [`japanese-tech-writing`](../../.agents/skills/japanese-tech-writing/SKILL.md) に従う

## ディレクトリ規約

```text
App/TestDocs/
  README.md
  AGENTS.md
  _TEMPLATE.md
  coverage-strategy.md
  IT/
    F001/
      DS01.md
```

- パス: `App/TestDocs/IT/F{番号}/{区分}{連番}.md`
- 観点 ID: `IT-F{番号}-{区分}{連番}`（例: `IT-F001-DS01`）
- 1 ファイル = 1 シナリオ（観点 ID）
- front matter: `id` / `title` / `primary_domain` / `platforms` / `status` / `issue`（任意）
- `platforms` は `[macOS]` 固定（本文に `## 対象` は書かない）
- 節の順は **シナリオ → 完了条件 → 経路 → 対応済みPR**（[`_TEMPLATE.md`](_TEMPLATE.md)）
- **完了条件**は手段ごとのステップ箇条書き。原則 **UT&IT / VRT**。E2E は必要なときだけ
- **経路**は実装するテスト単位。見出しは振る舞いのみ（クラス名禁止）。その下に GWT
- Then は Store / Settings / 表示状態を主検証とする

### primary_domain の目安

| domain | 扱うもの |
| --- | --- |
| `Budget` | 予算バー、しきい値、通知 |
| `Cost` | コスト集計、モデル別、セッション |
| `Cursor` | Cursor 従量 / included 枠 / サインイン状態 |
| `Settings` | 設定画面、表示モード、通貨 |
| `MenuBar` | メニューバー表示 |

区分（`DS` 表示、`LC` ライフサイクルなど）はパスと `id` から読みます。本文に「## 区分」は書きません。

## front matter の status

| Status | 意味 |
| --- | --- |
| `ideation` | 壁打ち中。GWT がまだ実装に足りない |
| `ready` | 実装着手可 |
| `in-progress` | 実装ブランチ作業中 |
| `review` | PR レビュー中（任意） |
| `done` | 実装完了。テスト通過後、マージ前の実装 PR で更新してよい |

## 実行コードの置き場

| 手段 | 置き場 |
| --- | --- |
| UT / IT | [`../Tests`](../Tests/) |
| VRT 土台 | `ScreenshotRenderer` / `ui-preview`（自動ピクセル比較は後続） |
| E2E | [`../E2E`](../E2E/) |

Site のシナリオはここに置きません。
