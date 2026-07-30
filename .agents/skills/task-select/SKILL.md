---
name: task-select
description: >-
  GitHub Issues から次に取り組むタスクを選ぶ。「次のタスクを検討して」「タスクを選定して」
  「次に進めるべきタスクを」のように、次に実装する項目を選んでほしいと言われたときに使う。
  オープンな Issue を取得し、ラベルや条件で絞り、根拠付きの候補を順位付けして提示する。
  読み取り専用で、実装もブランチ作成も PR 作成もしない。
---

# タスク選定

オープンな GitHub Issue を見渡して、次のタスクを推薦する。これは**読み取り専用の助言**スキルで、
機能の実装もブランチの作成もしない。

## 手順

1. **オープンな Issue を取得する**

   ```bash
   gh issue list --repo Tokfuel/Tokfuel --state open --limit 50 \
     --json number,title,labels,body 2>/dev/null
   ```

   進行中の作業を踏まないよう、オープンな PR も確認する。

   ```bash
   gh pr list --repo Tokfuel/Tokfuel --state open --limit 20 \
     --json number,title,headRefName 2>/dev/null
   ```

2. **絞り込む**。ユーザーの条件（「バグだけ」「enhancement だけ」、特定のトピック）があれば
   それに従う。主なラベルは `enhancement 🚀` と `bugs 🐞`（ほかに `docs ✍️` や `chore 🏠` など）。

3. **候補を順位付けする**。観点は次のとおり。
   - 依存関係：他の Issue のブロックを外すものを上位に置く（本文の `#N` 参照を確認する）。
   - スコープ：1 セッションで完了できるものを優先する。
   - トピックの近さ：同じ領域の Issue はコンテキストを共有できる。
   - グラウンドルールとの相性：ローカルオンリー、ゼロセットアップ、retok 無改変にきれいに
     収まる Issue は、枠に力がかかる Issue よりリスクが低い。

4. **提示する**。3〜5 件の短い順位付きリストにし、それぞれに Issue 番号とタイトル、一行の
   根拠、注意すべきブロッカーや依存を添える。

5. **ユーザーの選択を待つ**。選ばれたら、Issue 番号を渡して
   [`/implementation`](../implementation/SKILL.md) で始めることを勧める
   （例: `/implementation #5`）。

## このスキルがしないこと

- 機能の実装やコードの変更。
- ブランチや PR の作成。
- Issue のクローズや編集。
