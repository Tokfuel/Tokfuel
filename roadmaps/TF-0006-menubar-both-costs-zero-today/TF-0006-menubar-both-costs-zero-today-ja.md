[English](TF-0006-menubar-both-costs-zero-today.md) · **日本語**

# TF-0006 — バグ: 「今日と今月」表示で今日が 0 のとき月額まで消える

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0006](TF-0006-menubar-both-costs-zero-today-ja.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| Topic | バグ · メニューバー |
| Origin | ユーザー報告（2026-07） |
<!-- /TF-METADATA -->

## Introduction

メニューバー表示を「今日と今月のコスト」（`bothCosts`）にしている状態で、今日の利用
トークン数が 0 だと、表示**全体**がプロンプト数のフォールバックに落ち、分かっているはずの
月額まで消えてしまいます。

## Motivation

使っていない日こそ「今月ここまでいくら」を見たいはずです。それが消えると表示が壊れた
ように見え、両方表示モードの意味がなくなります。

## Detailed design

原因: `AppDelegate.updateStatusTitle` の `bothCosts` 分岐が `todayFigure()` の non-nil を
前提にしています。`todayFigure()` は `usageStore.todayCost` が nil のとき nil を返し、
これは retok レポートの `daily` に今日の行が無い（まだ利用していない）場合に起きます。
続く `else if` の連鎖で、`monthFigure()` が取れるにもかかわらず月額ごと落ちます。

修正案:

- 「今日の行が無い」を欠損ではなく **$0.00** として扱う: レポート取得済みで今日の行が
  無ければ `todayCost` が `0` を返すようにするか、`todayFigure()` 側で処理する。
  （本当に「レポート未取得」の場合は nil のままにし、起動直後のプロンプト数
  フォールバックは維持する。）
- `bothCosts` 分岐は両方を前提にせず、取れた値をそれぞれ独立に表示する。
- ユニットテストを追加: 今日の行が無いレポート → 今日は `$0.00` と整形され、
  月額の値も生成されること。

## Alternatives considered

- `if let` の順序を入れ替えるだけ（月のみのフォールバック追加）— 「利用 0 の日は
  $0.00 と読めるべき」という本質を隠したままになるため不十分です。

## Progress

- [ ] `todayCost` の意味論: 取得済みで行が無い日 = 0
- [ ] `bothCosts` 分岐の独立表示
- [ ] 利用 0 の日のユニットテスト

## References

- `Tokfuel/Sources/App.swift` — `updateStatusTitle` / `todayFigure`
- `Tokfuel/Sources/UsageStore.swift` — `todayCost`
