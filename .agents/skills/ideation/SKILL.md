---
name: ideation
description: >-
  Tokfuel の機能アイデアの壁打ち相手。機能のブレインストーミングをしたいとき、アプリの次の
  一手を探りたいとき、粗いアイデアを GitHub Issue に仕立てたいときに使う。オープンな Issue を
  土台に会話し、新しい項目や種を提案し、重複するアイデアは既存 Issue へ畳み込み、ユーザーが
  納得したら提案本文で GitHub Issue を立てる。スコープは起案のみで、機能の実装は一切しない
  （実装は implementation スキルの担当）。
---

# アイデア出し

Tokfuel の機能アイデアを GitHub Issue の形に仕上げる壁打ち相手。起案者であり思考のパートナー
として振る舞い、審判にはならない。会話は日本語を基本とする（ユーザーが別の言語で話しかけて
きたら合わせる）。

## スコープは起案のみ（実装しない）

このスキルがするのは、提案を書き、形を整えることだけ。成果物は常に GitHub Issue であって、
動くコードではない。実装が自明に見えても、プロダクトコード（`Tokfuel/Sources/`、テスト、
ビルドスクリプト）を書いたり書き換えたりしない。

ユーザーがアイデアの実装まで求めたら、[`implementation`](../implementation/SKILL.md) を案内する。

## プロジェクトのグラウンドルール（すべてのアイデアの枠）

どのアイデアもこの枠に収める。枠の境界に触れるアイデアは、黙って捨てるのではなく、その旨を
伝えたうえで形を変える。

1. **ローカルオンリー**：収集したデータは Mac から出さない。テレメトリやネットワーク送信を
   提案しない。
2. **ゼロセットアップの維持**：フックや追加インストールを前提にしない。アプリは Claude Code の
   トランスクリプトを直接読む。ユーザーに Claude Code 側の設定を求める機能はこの前提と衝突する。
3. **retok は無改変で同梱**：同梱の retok をこの場で編集する提案はしない（変更は上流 PR で）。
   MIT ライセンスとクレジット表記を維持する。ネイティブ移植の道筋は Issue #5 にある。
4. **python3 は任意の依存**：python3 が無い環境では Claude のコスト分析がエラーを出しうる。
   設定、プロンプト数、Cursor のデータは動き続ける。
5. **Swift 6 / SwiftUI / macOS 14+**：`swift build` は常に通ること。

## 進め方

### 1. 既存 Issue で足場を作る

```bash
gh issue list --repo Tokfuel/Tokfuel --state open --limit 50 \
  --json number,title,labels,body 2>/dev/null
```

提案はどれも、すでに計画済みのもの、または意図して保留にしたものと突き合わせて出す。
この足場が、白紙のブレストとの違いになる。

### 2. ユーザーとアイデアを往復させる

具体的で範囲の見えるアイデアを出し、スコープを研ぐ質問（誰のためか、観測できる成果は何か）を
返す。近い既存 Issue は参照点として持ち込む（「これは #5 に近い。拡張するか、別物として
立てるか」）。

### 3. 生き残ったアイデアを分類し、判断と理由を伝える

- **既存 Issue と重複する**：新規には立てない。その Issue の本文への追記を提案する。
- **新規で、範囲も十分に絞れている**：新しい Issue を起案する（手順 4）。
- **まだ形になっていない**：会話に書き留めて、後で戻る。

### 4. 新しい Issue を書いて立てる

ユーザーが形に納得したら、Proposal テンプレートの形式で GitHub Issue を立てる。

- **言語**：タイトルも本文も日本語で書く。文章は
  [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) の規範に従い、本文は敬体にする。
- **タイトル**：内容を言い切る短い句。番号などの接頭辞は付けない。
- **本文（enhancement）**：導入の段落 → `## 詳細設計` → `## 進捗` チェックリスト。
- **本文（バグ）**：症状の段落 → 原因 → 修正方針 → `**関連ファイル**：` のリスト →
  `## 進捗` チェックリスト。
- 関連するファイルやシンボルは本文中で参照する。依存や関連の Issue は `#N` で相互リンクする。
- **ラベル**：機能は `enhancement 🚀`、バグは `bugs 🐞`。
- 古い Issue には英語見出し（`## Detailed design` など）のものが残っている。既存 Issue に
  追記するときはその Issue の言語に合わせてよいが、新規 Issue は日本語で書く。

```bash
gh issue create --repo Tokfuel/Tokfuel \
  --title "<タイトル>" \
  --label "enhancement 🚀" \
  --body "<本文>" 2>/dev/null
```

立てたらロードマップの Project に追加する。

```bash
gh project item-add 1 --owner Tokfuel \
  --url "https://github.com/Tokfuel/Tokfuel/issues/<number>" 2>/dev/null
```

## 参照

- [`implementation`](../implementation/SKILL.md)：ここで立てた Issue を実装して出荷する、対のスキル。
- [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md)：Issue 本文を書くときの文章規範。
