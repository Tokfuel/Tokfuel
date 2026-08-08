# TestDocs（テストシナリオ）

作業規範は [`AGENTS.md`](AGENTS.md) を参照してください。

Tokfuel アプリのテスト観点を git 上の Markdown として管理します。  
メニューバーアプリ向けに、ドメイン直下の連番とスラッグで観点を置きます。

1. **起票**: 壁打ちし、OK 後にシナリオ MD を追加する（プロダクトコードは触らない）
2. **実装**: シナリオ MD を正本に E2E（必要なら UT / IT / VRT）を書き、`status` と対応済みPR を更新する
3. **日本語**: Issue / PR / シナリオ本文は [`japanese-tech-writing`](../../../.agents/skills/japanese-tech-writing/SKILL.md) に従う

## ディレクトリ規約

```text
App/Tests/TestDocs/
  README.md
  AGENTS.md
  _TEMPLATE.md
  CATALOG.md
  coverage.json
  MenuBar/
  Cost/
  Settings/
  Budget/
  Cursor/
```

- パス: `App/Tests/TestDocs/{Domain}/{nn}-{slug}.md`
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
| `archived` | UI や仕様の変化で現行の正本ではなくなった。履歴として残す |

### UI 変更でシナリオが合わなくなったとき

既存シナリオの本文や GWT を書き換えて追従しない。古いファイルは `status: archived` にし、必要な観点は **新しい ID**（同じドメインの次の連番）で新規起票する。

- アーカイブする MD の本文は原則そのまま残す（履歴の正）
- 任意で front matter に `superseded_by: {Domain}-{nn}-{slug}` を足し、後任の観点 ID を示す
- カバレッジの母数からは `archived` を除く（現行シナリオだけを見る）

## 担保手段

完了条件で使う手段の優先と境界です。シナリオ MD の書き方は [`_TEMPLATE.md`](_TEMPLATE.md) を正とします。

### 原則

1. **E2E** でユーザー操作に近い通しを担保する
2. **UT&IT** は、通しだけでは脆い計算や表示用モデルの組み立てを補助する
3. **VRT** は、見た目の固定が要る観点だけに足す

同じ観測を手段のあいだで二重にテストしない。E2E で既に観測できる表示を、同じ期待のまま UT&IT に複製しない。

### E2E

シナリオの主たる完了条件です。

- 置き場: [`../E2E`](../E2E/)
- Maestro / Appium / 別リポジトリは持ち込まない
- ウィンドウサーバが必要（手元の Mac、または ui-preview と同じ種類の CI ランナー）
- 見た目のピクセル回帰は E2E ではなく VRT に置く
- 実ユーザーの `~/Library/Application Support/Tokfuel` は触らない。フィクスチャ注入で再現する

### UT&IT

通しでは観測しづらい振る舞いを補助します。

- 置き場: [`../UnitTests`](../UnitTests/)
- 実行: `swift test`
- 当面はフィクスチャと部分モックで完結してよい
- Then の主検証は Store / Settings / 表示用の状態とする

### VRT

見た目の回帰を止めます。

- 土台: `ScreenshotRenderer` のフィクスチャ描画と、Point-Free `swift-snapshot-testing`（`App/Tests/UnitTests`、参考画像は `__Snapshots__`）
- `ui-preview` は人間レビュー用の絵出しとして残す
- 完了条件の VRT は「対象画面がフィクスチャとして固定されている」ことを指す
- **設定フラグごとの画面パターン**（通貨、コストソース、外観、詳細／デバッグ開示、推移期間など）は、フラグが効いたあとの見え方をフィクスチャとして固定する。操作の通しは E2E、見た目は VRT に分ける
- 同じ期待を E2E と VRT で二重にしない
- 新規パッケージや外部 VRT SaaS は、オーナー承認なしでは入れない（`swift-snapshot-testing` はオーナー承認済みの例外）
- UI を変える PR では、`ScreenshotRenderer.allScreens()` / `ui-preview.yml` / 参考画像を同じ差分で更新する

### 対象外

- Site（`Site/`）のシナリオ。別系統で必要になったら `Site/` 側に置く
- 実ユーザーの `~/Library/Application Support/Tokfuel` を触るテスト
- 利用データを Mac の外へ出す検証

<!-- testdocs-coverage:start -->
## カバレッジ

主指標の **実装カバレッジ** はいま **0.0%**（`0/132`、現行のみ。archived 除外）です。着手カバレッジは 15.9%（`21/132`）、起票完了率は 100.0%（`132/132`）、E2E 完了条件の記載率は 100.0%（`132/132`）です。

定義とドメイン別内訳は [`CATALOG.md`](CATALOG.md) の「カバレッジ」節、機械可読な値は [`coverage.json`](coverage.json) を見てください。

```bash
python3 Scripts/generate-testdocs-catalog.py
```

<!-- testdocs-coverage:end -->

## シナリオ索引

全件の一覧とカバレッジは [`CATALOG.md`](CATALOG.md) を見てください。

シナリオを追加・変更したら、次で索引を再生成します。

```bash
python3 Scripts/generate-testdocs-catalog.py
```
