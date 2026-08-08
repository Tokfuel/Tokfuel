---
title: "SPM を feature 縦割りで分割し、並行 PR の衝突面を減らす"
status: Proposed
proposed: 2026-08-08
accepted:
supersedes:
issue: "#109"
---

# SPM を feature 縦割りで分割し、並行 PR の衝突面を減らす

[English](./0002-feature-spm-modules.md)

## Decision（決定事項）

> アーキテクチャやソリューションの意思決定の内容

### 決定事項

`App/` 配下の単一 SPM target をやめ、**変更が寄りやすい軸（feature）で library target を縦割り**する。第一の目的は **無関係な Issue / PR 同士の衝突面を減らす**ことである。

- 分割軸の例: Claude / Cursor / Codex / Budget / Settings。横断型だけ薄い `TokfuelCore`（名称は実装時に確定）に置く
- `UsageStore`（各ソースの合算）と `PopoverView` など（メニューバー周りの枠）は、複数 feature が触る**共有部分**として残る。ただし Cursor 行の描画や Claude 固有の集計のような**ソース固有の中身は各 feature target に置き**、共有部分には「並べる・足す・枠を出す」だけを残す
- Firebase・retok リソース・sqlite3 は、使う feature / Analytics target に閉じる
- **レイヤー依存（UI → Store → drivers など）のコンパイル強制は、本決定では採らない**。上記の共有部分（合算と枠 UI）が残る以上、feature 縦割りによる衝突低減と、レイヤー target による依存強制を同じ SPM 構成で両立できなかった。層の向きは AGENTS.md と AI コーディング（スキル・レビュー）で担保する
- 挙動とグラウンドルール（ローカルオンリー、ゼロセットアップ、retok 無改変、python3 任意、新規パッケージ禁止）は変えない

配置の親は ADR-0001 のとおり `App/` のままとする。本決定は **target / モジュール境界** の話であり、ディレクトリ親の再配置ではない。

### 構成図

現状（単一 target・フラット。衝突面が大きい）:

```mermaid
flowchart TB
  subgraph AppTokfuel["App/Tokfuel（単一 executable）"]
    UI["PopoverView / SettingsView / …"]
    Store["UsageStore"]
    Claude["Claude / retok"]
    Cursor["Cursor drivers / services"]
    Codex["Codex drivers"]
    Budget["BudgetMonitor"]
    Settings["AppSettings"]
    Coreish["LocalDay / Money / CostDriver …"]
  end
  UI --- Store
  Store --- Claude
  Store --- Cursor
  Store --- Codex
  Store --- Budget
  Store --- Settings
  UI --- Coreish
  Store --- Coreish
```

採用する feature 縦割り（矢印は App からの組み立て。レイヤーは規約）:

```mermaid
flowchart TB
  App["TokfuelApp<br/>executable・組み立て"]
  Shared["共有部分<br/>UsageStore の合算<br/>Popover など枠 UI"]
  Settings["TokfuelSettings"]
  Claude["TokfuelClaude<br/>Claude 固有の表示・集計"]
  Cursor["TokfuelCursor<br/>Cursor 固有の表示・集計"]
  Codex["TokfuelCodex"]
  Budget["TokfuelBudget"]
  Analytics["TokfuelAnalytics"]
  Core["TokfuelCore<br/>横断型のみ"]

  App --> Shared
  App --> Settings
  App --> Claude
  App --> Cursor
  App --> Codex
  App --> Budget
  App --> Analytics
  App --> Core

  Shared --> Settings
  Shared --> Claude
  Shared --> Cursor
  Shared --> Codex
  Shared --> Budget
  Shared --> Core

  Claude --> Core
  Cursor --> Core
  Codex --> Core
  Budget --> Core
  Settings --> Core
  Analytics --> Core
```

衝突面の狙い（第一目的）:

```mermaid
flowchart LR
  subgraph before["現状: 同じ木で交差しやすい"]
    Flat["単一フラット階層"]
  end
  subgraph after["採用後: 無関係な変更が分かれやすい"]
    C[Claude]
    Cu[Cursor]
    Co[Codex]
    B[Budget]
  end
  subgraph residual["残る共有部分<br/>中身は並べる・足す・枠だけにする"]
    S[UsageStore 合算]
    U[Popover など枠]
  end
  C --> S
  Cu --> S
  Co --> S
  B --> S
  S --> U
```

名称（`Tokfuel*`）は実装時に確定してよい。図の意図は「feature を縦に割って衝突を減らし、共有部分にはソース固有の中身を置かない」こと。レイヤーの正しさは図の target 線では表さない。

### 例（共有部分と feature の切り方）

UIKit で言う micro ViewController に近い考え方だが、ここでは child VC 分割ではなく **feature target に塊を寄せる**。親は組み立て役に留める。

**例1: ポップオーバーに Cursor の行を足す**

| | 現状に近い書き方 | この ADR が狙う書き方 |
|--|------------------|----------------------|
| 触る場所 | `PopoverView.swift` に Cursor 用の `Text` / 色 / ラベルを直接追加する | `TokfuelCursor` に `CursorCostRow` のような View を置き、`PopoverView` はそれを並べるだけ |
| 衝突 | Budget の枠修正 PR と、同じ `PopoverView` でぶつかりやすい | Cursor の PR は `TokfuelCursor` 側に閉じやすい |

**例2: Cursor の今日分コスト表示を直す**

| | 現状に近い書き方 | この ADR が狙う書き方 |
|--|------------------|----------------------|
| 触る場所 | `UsageStore` に Cursor 用の計算や表示用プロパティが増えていく | Cursor 側の集計は `TokfuelCursor` に置き、`UsageStore` は「Claude + Cursor + … を足した合計」と配線だけを持つ |
| 衝突 | Claude 合算の修正と巨大な `UsageStore` で交差しやすい | Cursor 集計の修正は feature 側に閉じやすい |

**共有部分に残してよいもの / 寄せるもの**

| 共有部分に残す（並べる・足す・枠） | feature に寄せる（ソース固有） |
|----------------------------------|--------------------------------|
| ポップオーバーの枠、タブ、更新ボタン | 「Cursor（推定）」行の文言・色・レイアウト |
| 全ソース合計金額の表示 | Claude / retok セッション一覧の並びやバッジ |
| `UsageStore` が各 feature の値を合算する配線 | Cursor ダッシュボード取得や Codex セッション読取 |

名前や型は実装時の仮でよい。重要なのは「Cursor を直す PR が `PopoverView` / `UsageStore` の奥深くまで入らない」こと。

### 比較・検討内容の要約

衝突低減（feature 縦割り）と依存強制（レイヤー target）の両方を同じアーキテクチャで満たそうとすると、`UsageStore` の合算と `PopoverView` などの枠という共有部分が残り、ハイブリッドでも衝突第一の効果が頭打ちになる。両立できなかったため、**並行 PR の衝突低減を採り、レイヤーは規約 + AI に残す**。レイヤーのみは衝突面が Store / UI に集まりやすい。極細多数レイヤーはこの規模では過大。

## Context（経緯・背景情報）

> この意思決定が行われる背景、問題点、目的など

### 背景

アプリ本体は `App/Tokfuel/` にフラットに置かれ、`Package.swift` は単一の executable target である（ADR-0001 で親を `App/` に揃えたあとも、target は一つ）。UI・Store・外部通信・コスト計算が同一ディレクトリ・同一 target に混在している（#109）。

OSS として複数の Issue / PR が並ぶと、無関係な変更が同じ巨大ファイルや同じ階層でぶつかりやすい。コントリビュータにも「この変更はどの箱か」が見えにくい。一方、Store / UI / driver の役割分担は AGENTS.md に既にあり、AI セッションでもその規約を読ませて守らせられる。

### 課題

1. **並行 PR の衝突面が大きい**（第一）
   - フラットな単一 target だと、Cursor 修正と予算修正のような無関係な作業も同じ木で交差しやすい。
2. **変更範囲が切りにくい**
   - 新機能やソース追加のとき、触るべきファイル集合がディレクトリ名から読み取りにくい。
3. **共有部分にソース固有の中身が残ると、feature 分割の効果が削がれる**
   - Cursor の行追加なのに `PopoverView` や巨大な `UsageStore` ばかり触る状態が続くと、縦割りの利点が薄れる。
4. **衝突低減とレイヤー強制を同じ SPM 構成で両立できない**
   - 合算と枠 UI は製品上の共有部分として残る。ここにレイヤー target を足しても、無関係 PR の交差は同程度残り、feature 縦割り以上の衝突低減にはならない。

### 目的

- 無関係な Issue 同士の衝突面を小さくする（両立できなかった二目標のうち採る側）
- コントリビュータが変更範囲を切りやすくする
- ソース固有の表示・集計を feature に移し、共有部分は並べる・足す・枠だけにする
- 採らなかった側（レイヤー強制）は AGENTS + AI コーディングで補う
- `swift test` / `swift build -c release` を各段階で緑に保つ

## Consideration（比較・検討内容）

> 他に検討した選択肢や検討した内容

### 比較対象

| 案 | ソリューション | 概要 |
|----|----------------|------|
| 案1 | **現状維持** | 単一 target・フラット配置のまま |
| 案2 | **レイヤーのみ** | UI / Store / Services / Core などに割る。feature は分けない |
| 案3 | **feature 縦割り** | Claude / Cursor / Codex / Budget などに割る。レイヤーは規約 + AI |
| 案4 | **極細レイヤー多数** | feature 内まで Interface / Data 等を細かく target 化 |
| 案5 | **ハイブリッド** | feature 縦割り + レイヤー依存を SPM でも強制 |

### 比較表

第一評価軸は「並行 PR の衝突低減」。

| 評価項目 | 案1 現状維持 | 案2 レイヤーのみ | 案3 feature 縦割り | 案4 極細多数 | 案5 ハイブリッド |
|----------|--------------|------------------|--------------------|--------------|------------------|
| 並行 PR の衝突低減（第一） | × ホットスポットが大きい | △ Store / UI に集まりやすい | ◎ 無関係 Issue が分かれやすい | ○ 分かれるが運用が重い | ◎ 案3と同程度。合算・枠 UI の共有は同様に残る |
| 変更範囲の切りやすさ | × 入口が一つ | △ 「何層か」は分かるが機能軸が弱い | ◎ 「どのソースか」で切れる | △ target 数が多すぎる | ◎ 機能軸は同じ。層の箱が増える |
| レイヤー担保 | △ 規約 + AI | ◎ コンパイルで向きを固定 | △ 規約 + AI（採らなかった側の補完） | ◎ さらに細かい | ◎ 層は強制できるが、共有面の衝突は案3と同程度 |
| 移行コスト | ◎ 変更不要 | ○ 中程度 | ○ 中程度 | × この規模では過大 | △ 案3より重い（層 target の追加分） |
| 二目標の両立 | × どちらも弱い | × 衝突が弱い | ○ 衝突を採り、層は外に出す | × 過大 | × 両方採ったつもりでも共有面で衝突が残る |

### 総合評価

| 案 | 総合評価 | 判定 |
|----|----------|------|
| 案1: 現状維持 | 衝突面の課題が残る | **不採用** |
| 案2: レイヤーのみ | 衝突低減と両立しない | **不採用** |
| 案3: feature 縦割り | 両立できない二目標のうち衝突低減を採る。層は規約 + AI | **採用** |
| 案4: 極細多数 | きれいさに対して移行・運用コストが過大 | **不採用** |
| 案5: ハイブリッド | 層と衝突の両立を狙うが、共有面が残り両立にならない | **不採用** |

## Consequences（結果）

> 予期される結果。意思決定がシステムやプロジェクトに与える影響

### 期待される効果

1. Cursor 修正と Budget 修正のような無関係な PR が、別 target / ディレクトリに分かれやすくなる
2. 「この Issue は `TokfuelCursor` を見ればよい」のように、変更範囲を説明しやすくなる
3. ソース固有 UI / 集計を feature に寄せるほど、`UsageStore` / `PopoverView` 上の衝突も減らせる

### 技術的リスクと対策

| リスク | 内容 | 対策 |
|--------|------|------|
| 合算・枠 UI のホットスポット | `UsageStore` と `PopoverView` は共有のまま残りやすい | Cursor 行などは `TokfuelCursor` 側の View / 集計に移す。共有側は合計と枠の組み立てだけにする |
| レイヤー逆流 | 両立できなかった側。SPM では止めないため UI が driver を直接見ることがありうる | AGENTS.md を維持。AI 実装・レビューで検知。共有部分を減らしたあとなお必要なら別 ADR で層 target を検討する |
| target 数の増加 | `Package.swift` と import が重くなる | Core を薄く保つ。極細レイヤー（案4）やハイブリッド（案5）にはしない |
| 逆依存の残留 | `BudgetMonitor`→UI、`AppSettings`→driver などが分割を阻む | target を切る前に callback / プロトコル化でほどく |
| リソース移設 | retok の `Bundle.module` や Firebase plist の場所がずれる | Claude / Analytics 側へ移し、`swift test` と実機相当で確認 |
| 移行の巨大化 | 一気にやるとレビューが重い | Core → Settings → sources → 共有部分の中身移設 → App の順。必要なら PR を段階分割する |

## References（参照）

> 関連リンク

- Issue: [#109](https://github.com/Tokfuel/Tokfuel/issues/109)
- PR: https://github.com/Tokfuel/Tokfuel/pull/148
- 関連 ADR: [0001-app-tree](../0001-app-tree/0001-app-tree.ja.md)（`App/` への集約。本決定の前提）
- 外部: （なし）
