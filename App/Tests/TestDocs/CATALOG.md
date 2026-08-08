# シナリオ一覧（網羅確認用）

TestDocs の全シナリオをドメイン別に並べた索引です。網羅の抜け漏れ確認に使います。
個別シナリオの正本は各 MD、運用規約は [`AGENTS.md`](AGENTS.md)、手段の優先は [`README.md`](README.md) の「担保手段」節です。

このファイルと [`coverage.json`](coverage.json) はシナリオ MD から生成します。シナリオを足したら同じ手順で更新してください。

```bash
python3 Scripts/generate-testdocs-catalog.py
```

## カバレッジ

シナリオ MD の front matter と節から、スクリプトが決定的に集計します。主指標は **実装カバレッジ**（`status: done` / 現行シナリオ。`archived` は母数外）です。

- 現行シナリオ: `132` / 全ファイル: `132` / archived: `0`
- 生成: `python3 Scripts/generate-testdocs-catalog.py`
- 機械可読: [`coverage.json`](coverage.json)

### 全体

| 指標 | 率 | 件数 | 定義 |
| --- | ---: | ---: | --- |
| 実装カバレッジ | 100.0% | `132/132` | status が done のシナリオ数 / 現行シナリオ数（archived を除く） |
| 着手カバレッジ | 100.0% | `132/132` | status が in-progress / review / done のシナリオ数 / 現行シナリオ数（archived を除く） |
| 起票完了率 | 100.0% | `132/132` | status が ideation 以外の現行シナリオ数 / 現行シナリオ数（archived を除く） |
| E2E 完了条件の記載率 | 100.0% | `132/132` | 完了条件に E2E がある現行シナリオ数 / 現行シナリオ数（archived を除く） |
| 対応済み PR 紐付け率 | 15.9% | `21/132` | 対応済みPR に pull リンクまたは #NNNN がある現行シナリオ数 / 現行シナリオ数（archived を除く） |

### ドメイン別の実装カバレッジ

| Domain | 実装カバレッジ | done / 現行 | archived |
| --- | ---: | ---: | ---: |
| MenuBar | 100.0% | `33/33` | 0 |
| Cost | 100.0% | `26/26` | 0 |
| Settings | 100.0% | `37/37` | 0 |
| Budget | 100.0% | `18/18` | 0 |
| Cursor | 100.0% | `18/18` | 0 |

### status 内訳

| status | 件数 |
| --- | ---: |
| `ideation` | 0 |
| `ready` | 0 |
| `in-progress` | 0 |
| `review` | 0 |
| `done` | 132 |
| `archived` | 0 |
| **合計** | **132** |

## 件数

| Domain | 件数 |
| --- | ---: |
| MenuBar | 33 |
| Cost | 26 |
| Settings | 37 |
| Budget | 18 |
| Cursor | 18 |
| **合計** | **132** |

## status の見方

| status | 意味 |
| --- | --- |
| `ideation` | 壁打ち中 |
| `ready` | 実装着手可 |
| `in-progress` | 実装中 |
| `review` | レビュー中 |
| `done` | 実装完了 |
| `archived` | UI / 仕様変化で現行外（書き換えず履歴として残す） |

## MenuBar（33）

| ID | title | status | 完了条件 |
| --- | --- | --- | --- |
| [`MenuBar-01-open-home`](MenuBar/01-open-home.md) | メニューバーからホーム（ポップオーバー）を表示できる | done | E2E, VRT |
| [`MenuBar-02-close-outside`](MenuBar/02-close-outside.md) | ホーム外をクリックするとポップオーバーが閉じる | done | E2E |
| [`MenuBar-03-toggle-reopen`](MenuBar/03-toggle-reopen.md) | メニューバーアイコンの再操作でホームを閉じられる | done | E2E |
| [`MenuBar-04-hero-today-cost`](MenuBar/04-hero-today-cost.md) | ホームのヒーローに今日のコストが表示される | done | E2E |
| [`MenuBar-05-footer-last-updated`](MenuBar/05-footer-last-updated.md) | フッターに最終更新時刻が表示される | done | E2E |
| [`MenuBar-06-footer-reload`](MenuBar/06-footer-reload.md) | 再読み込みで集計が更新される | done | E2E, UT&IT |
| [`MenuBar-07-footer-quit`](MenuBar/07-footer-quit.md) | メニューから Tokfuel を終了できる | done | E2E |
| [`MenuBar-08-open-about`](MenuBar/08-open-about.md) | メニューから Tokfuel についてを開ける | done | E2E |
| [`MenuBar-09-status-amount-today`](MenuBar/09-status-amount-today.md) | メニューバーに今日の金額が表示される | done | E2E |
| [`MenuBar-10-status-amount-month`](MenuBar/10-status-amount-month.md) | メニューバーに今月の金額が表示される | done | E2E |
| [`MenuBar-11-status-amount-both`](MenuBar/11-status-amount-both.md) | メニューバーに今日と今月の金額が表示される | done | E2E |
| [`MenuBar-12-status-prompts`](MenuBar/12-status-prompts.md) | メニューバーにプロンプト数が表示される | done | E2E |
| [`MenuBar-13-status-percent`](MenuBar/13-status-percent.md) | メニューバーにパーセント表示が出る | done | E2E |
| [`MenuBar-14-status-ring`](MenuBar/14-status-ring.md) | メニューバーにリングゲージだけが表示される | done | E2E |
| [`MenuBar-15-status-ring-and-value`](MenuBar/15-status-ring-and-value.md) | メニューバーにリングとパーセントが並ぶ | done | E2E |
| [`MenuBar-16-status-icon-only`](MenuBar/16-status-icon-only.md) | メニューバーがアイコンのみになる | done | E2E |
| [`MenuBar-17-gauge-shape-ring`](MenuBar/17-gauge-shape-ring.md) | ゲージの形がリングのとき円形インジケーターになる | done | E2E |
| [`MenuBar-18-gauge-shape-tank`](MenuBar/18-gauge-shape-tank.md) | ゲージの形がタンクのとき給油機が下から塗られる | done | E2E |
| [`MenuBar-19-ring-with-icon`](MenuBar/19-ring-with-icon.md) | リング表示時にアイコンも並べられる | done | E2E |
| [`MenuBar-20-percent-basis-budget`](MenuBar/20-percent-basis-budget.md) | 割合の基準が予算上限のとき予算に対する率が表示される | done | E2E, UT&IT |
| [`MenuBar-21-percent-basis-average`](MenuBar/21-percent-basis-average.md) | 割合の基準が日次平均のときペース比が表示される | done | E2E, UT&IT |
| [`MenuBar-22-shows-remaining`](MenuBar/22-shows-remaining.md) | 予算までの残り表示に切り替えられる | done | E2E |
| [`MenuBar-23-side-by-side-title`](MenuBar/23-side-by-side-title.md) | 並べて表示のときメニューバーにソース内訳が出る | done | E2E |
| [`MenuBar-24-unavailable-dash`](MenuBar/24-unavailable-dash.md) | 取得不能時メニューバーがダッシュになる | done | E2E |
| [`MenuBar-25-budget-icon-warning`](MenuBar/25-budget-icon-warning.md) | 予算しきい値到達でメニューバーアイコンが警告色になる | done | E2E |
| [`MenuBar-26-budget-icon-over`](MenuBar/26-budget-icon-over.md) | 予算超過でメニューバーアイコンが超過色になる | done | E2E |
| [`MenuBar-27-tooltip`](MenuBar/27-tooltip.md) | メニューバーアイコンのツールチップに指標説明が出る | done | E2E |
| [`MenuBar-28-adaptive-glow`](MenuBar/28-adaptive-glow.md) | 追従中の明滅がメニューバーアイコンに出る | done | E2E |
| [`MenuBar-29-update-button-offer`](MenuBar/29-update-button-offer.md) | 新バージョン検出時にアップデートボタンが出る | done | E2E, VRT |
| [`MenuBar-30-update-skip-version`](MenuBar/30-update-skip-version.md) | 提示中のバージョンをスキップできる | done | E2E |
| [`MenuBar-31-update-release-page`](MenuBar/31-update-release-page.md) | 差し替え不可環境ではリリースページを開くに変わる | done | E2E |
| [`MenuBar-32-update-retry`](MenuBar/32-update-retry.md) | 更新失敗時に再試行できる | done | E2E |
| [`MenuBar-33-open-on-launch-reload`](MenuBar/33-open-on-launch-reload.md) | ホームを開いたときに集計が走って数字が新しくなる | done | E2E |

## Cost（26）

| ID | title | status | 完了条件 |
| --- | --- | --- | --- |
| [`Cost-01-chart-style`](Cost/01-chart-style.md) | 推移グラフの表示形式を切り替えられる | done | E2E, VRT |
| [`Cost-02-period-switch`](Cost/02-period-switch.md) | 推移の期間を切り替え、表示が期間に追従する | done | E2E, UT&IT, VRT |
| [`Cost-03-model-list`](Cost/03-model-list.md) | モデル別セクションにモデル行が表示される | done | E2E |
| [`Cost-04-loading-parse`](Cost/04-loading-parse.md) | レポート未取得時に解析中表示が出る | done | E2E |
| [`Cost-05-stale-while-revalidate`](Cost/05-stale-while-revalidate.md) | 再解析中も前回のグラフが残る | done | E2E |
| [`Cost-06-retok-error`](Cost/06-retok-error.md) | retok 失敗時にエラー文が出る | done | E2E |
| [`Cost-07-chart-multi-source-legend`](Cost/07-chart-multi-source-legend.md) | 複数ソース時に推移の凡例が出る | done | E2E |
| [`Cost-08-chart-caption-total`](Cost/08-chart-caption-total.md) | 推移キャプションに期間合計が出る | done | E2E |
| [`Cost-09-chart-caption-prompt-unit`](Cost/09-chart-caption-prompt-unit.md) | 推移キャプションにプロンプト単価が出る | done | E2E |
| [`Cost-10-cumulative-budget-line`](Cost/10-cumulative-budget-line.md) | 累積グラフに予算の参照線が出る | done | E2E |
| [`Cost-11-cumulative-month-projection`](Cost/11-cumulative-month-projection.md) | 累積キャプションに月末の着地予測が出る | done | E2E |
| [`Cost-12-jpy-formatting`](Cost/12-jpy-formatting.md) | 円表示のときホームの金額が円表記になる | done | E2E, VRT |
| [`Cost-13-side-by-side-caption`](Cost/13-side-by-side-caption.md) | 並べて表示でヒーロー下にソース内訳キャプションが出る | done | E2E |
| [`Cost-14-cursor-only-label`](Cost/14-cursor-only-label.md) | Cursor のみのときヒーローに Cursor 推定ラベルが出る | done | E2E |
| [`Cost-15-unavailable-hero-dash`](Cost/15-unavailable-hero-dash.md) | 取得不能時ヒーロー金額がダッシュになる | done | E2E |
| [`Cost-16-model-breakdown-combined`](Cost/16-model-breakdown-combined.md) | モデル別をまとめて表示できる | done | E2E |
| [`Cost-17-model-breakdown-separated`](Cost/17-model-breakdown-separated.md) | モデル別をソース別に分けて表示できる | done | E2E |
| [`Cost-18-top-sessions`](Cost/18-top-sessions.md) | 高コストのセッション一覧が表示される | done | E2E, VRT |
| [`Cost-19-session-estimated-badge`](Cost/19-session-estimated-badge.md) | 二次ソースのセッションに推定表示が付く | done | E2E |
| [`Cost-20-advice-section`](Cost/20-advice-section.md) | 節約のヒントセクションが表示される | done | E2E, VRT |
| [`Cost-21-advice-expand`](Cost/21-advice-expand.md) | 節約のヒントを展開できる | done | E2E, VRT |
| [`Cost-22-advice-copy-prompt`](Cost/22-advice-copy-prompt.md) | 改善プロンプトをコピーできる | done | E2E |
| [`Cost-23-advice-source-badge`](Cost/23-advice-source-badge.md) | 節約のヒントにソース表示が付く | done | E2E |
| [`Cost-24-csv-export-daily`](Cost/24-csv-export-daily.md) | 日別 CSV を書き出せる | done | E2E |
| [`Cost-25-csv-export-monthly`](Cost/25-csv-export-monthly.md) | 月別 CSV を書き出せる | done | E2E |
| [`Cost-26-csv-export-disabled`](Cost/26-csv-export-disabled.md) | レポート未取得時は CSV 書き出しが無効になる | done | E2E |

## Settings（37）

| ID | title | status | 完了条件 |
| --- | --- | --- | --- |
| [`Settings-01-open`](Settings/01-open.md) | ポップオーバーから設定を開ける | done | E2E, VRT |
| [`Settings-02-reflect`](Settings/02-reflect.md) | 設定の変更がポップオーバー／メニューバー表示に反映される | done | E2E, UT&IT |
| [`Settings-03-launch-at-login`](Settings/03-launch-at-login.md) | ログイン時に自動起動を切り替えられる | done | E2E |
| [`Settings-04-appearance`](Settings/04-appearance.md) | 外観の切替が各ウィンドウに反映される | done | E2E, VRT |
| [`Settings-05-cost-source-combined`](Settings/05-cost-source-combined.md) | コストのソースを合算にできる | done | E2E, VRT |
| [`Settings-06-cost-source-claude-only`](Settings/06-cost-source-claude-only.md) | コストのソースを Claude のみにできる | done | E2E, VRT |
| [`Settings-07-cost-source-cursor-only`](Settings/07-cost-source-cursor-only.md) | コストのソースを Cursor のみにできる | done | E2E |
| [`Settings-08-cost-source-codex-only`](Settings/08-cost-source-codex-only.md) | Codex がある環境で Codex のみを選べる | done | E2E |
| [`Settings-09-cost-source-side-by-side`](Settings/09-cost-source-side-by-side.md) | コストのソースを並べて表示にできる | done | E2E, VRT |
| [`Settings-10-model-breakdown-mode`](Settings/10-model-breakdown-mode.md) | モデル別の出し方を切り替えられる | done | E2E |
| [`Settings-11-week-start`](Settings/11-week-start.md) | 週の始まりの変更が推移の今週に効く | done | E2E, UT&IT |
| [`Settings-12-menu-bar-metric`](Settings/12-menu-bar-metric.md) | メニューバーの見る指標を切り替えられる | done | E2E |
| [`Settings-13-menu-bar-representation`](Settings/13-menu-bar-representation.md) | メニューバーの表現を切り替えられる | done | E2E |
| [`Settings-14-menu-bar-gauge-shape`](Settings/14-menu-bar-gauge-shape.md) | ゲージの形をリングとタンクから選べる | done | E2E |
| [`Settings-15-menu-bar-shows-icon`](Settings/15-menu-bar-shows-icon.md) | リング表示時にアイコンも並べるを切り替えられる | done | E2E |
| [`Settings-16-menu-bar-percent-basis`](Settings/16-menu-bar-percent-basis.md) | 割合の基準を切り替えられる | done | E2E |
| [`Settings-17-menu-bar-shows-remaining`](Settings/17-menu-bar-shows-remaining.md) | 予算までの残りを表示を切り替えられる | done | E2E |
| [`Settings-18-adaptive-refresh`](Settings/18-adaptive-refresh.md) | 使用中は更新を速めるを切り替えられる | done | E2E, UT&IT |
| [`Settings-19-activity-animation`](Settings/19-activity-animation.md) | 追従中の明滅を切り替えられる | done | E2E |
| [`Settings-20-budget-monthly-limit`](Settings/20-budget-monthly-limit.md) | 月の上限を設定できる | done | E2E |
| [`Settings-21-budget-daily-limit`](Settings/21-budget-daily-limit.md) | 1日の上限を設定できる | done | E2E |
| [`Settings-22-budget-period`](Settings/22-budget-period.md) | 月予算の集計期間を切り替えられる | done | E2E |
| [`Settings-23-budget-warn-threshold`](Settings/23-budget-warn-threshold.md) | 警告しきい値を切り替えられる | done | E2E |
| [`Settings-24-budget-alert-style`](Settings/24-budget-alert-style.md) | 予算の知らせ方を切り替えられる | done | E2E |
| [`Settings-25-privacy-analytics-toggle`](Settings/25-privacy-analytics-toggle.md) | 利用状況の送信許可を後から切り替えられる | done | E2E |
| [`Settings-26-advanced-disclosure`](Settings/26-advanced-disclosure.md) | 詳細を開くと高度な設定が見える | done | E2E, VRT |
| [`Settings-27-report-language`](Settings/27-report-language.md) | レポート言語を切り替えられる | done | E2E |
| [`Settings-28-claude-directory`](Settings/28-claude-directory.md) | Claude ディレクトリを変更しデフォルトに戻せる | done | E2E |
| [`Settings-29-event-log-toggle`](Settings/29-event-log-toggle.md) | 利用イベントの記録を切り替えられる | done | E2E |
| [`Settings-30-event-log-reveal`](Settings/30-event-log-reveal.md) | イベントログフォルダを表示できる | done | E2E |
| [`Settings-31-event-log-delete`](Settings/31-event-log-delete.md) | 全イベントログを削除できる | done | E2E |
| [`Settings-32-about-window`](Settings/32-about-window.md) | About にバージョンとクレジットが見える | done | E2E, VRT |
| [`Settings-33-analytics-consent-first-run`](Settings/33-analytics-consent-first-run.md) | 初回に利用状況送信の同意ダイアログが出る | done | E2E, VRT |
| [`Settings-34-analytics-consent-deny`](Settings/34-analytics-consent-deny.md) | 同意ダイアログで許可しないを選べる | done | E2E |
| [`Settings-35-menu-bar-preview-note`](Settings/35-menu-bar-preview-note.md) | 選べない表現のとき説明文が出る | done | E2E |
| [`Settings-36-currency-jpy-budget-unit`](Settings/36-currency-jpy-budget-unit.md) | 円とレート取得後に予算入力の単位が円になる | done | E2E, VRT |
| [`Settings-37-debug-disclosure`](Settings/37-debug-disclosure.md) | デバッグを開くと診断用の設定が見える | done | E2E, VRT |

## Budget（18）

| ID | title | status | 完了条件 |
| --- | --- | --- | --- |
| [`Budget-01-popover-daily-row`](Budget/01-popover-daily-row.md) | 1日上限があるときホームに今日の予算行が出る | done | E2E |
| [`Budget-02-popover-monthly-row`](Budget/02-popover-monthly-row.md) | 月上限があるときホームに月の予算行が出る | done | E2E |
| [`Budget-03-popover-hidden-when-off`](Budget/03-popover-hidden-when-off.md) | 上限未設定のとき予算セクションが隠れている | done | E2E |
| [`Budget-04-meter-ok-state`](Budget/04-meter-ok-state.md) | 平常時の予算メーターに消費と上限が見える | done | E2E |
| [`Budget-05-meter-warning-state`](Budget/05-meter-warning-state.md) | しきい値到達で予算メーターが警告状態になる | done | E2E |
| [`Budget-06-meter-over-state`](Budget/06-meter-over-state.md) | 超過で予算メーターが超過状態になる | done | E2E |
| [`Budget-07-meter-warn-marker`](Budget/07-meter-warn-marker.md) | 予算メーターに警告しきい値の目盛りが出る | done | E2E |
| [`Budget-08-notification-warning`](Budget/08-notification-warning.md) | しきい値到達を通知で知らせる | done | E2E |
| [`Budget-09-notification-over`](Budget/09-notification-over.md) | 上限超過を通知で知らせる | done | E2E |
| [`Budget-10-alert-window-warning`](Budget/10-alert-window-warning.md) | しきい値到達をアラートウィンドウで知らせる | done | E2E, VRT |
| [`Budget-11-alert-window-over`](Budget/11-alert-window-over.md) | 超過時アラートが超過向けの見え方になる | done | E2E |
| [`Budget-12-alert-open-settings`](Budget/12-alert-open-settings.md) | アラートから予算設定を開ける | done | E2E |
| [`Budget-13-alert-close`](Budget/13-alert-close.md) | アラートを閉じられる | done | E2E |
| [`Budget-14-alert-both-channels`](Budget/14-alert-both-channels.md) | 通知とアラートウィンドウの両方で知らせる | done | E2E |
| [`Budget-15-daily-vs-monthly-independent`](Budget/15-daily-vs-monthly-independent.md) | 日次と月次の予算が独立に判定される | done | E2E, UT&IT |
| [`Budget-16-side-by-side-still-combined`](Budget/16-side-by-side-still-combined.md) | 並べて表示でも予算の分母は合算のまま | done | E2E, UT&IT |
| [`Budget-17-auth-on-budget-set`](Budget/17-auth-on-budget-set.md) | 予算を初めて設定すると通知許可が求められる | done | E2E |
| [`Budget-18-period-reset-notify`](Budget/18-period-reset-notify.md) | 日付や月が替わると同じレベルでも再通知できる | done | E2E, UT&IT |

## Cursor（18）

| ID | title | status | 完了条件 |
| --- | --- | --- | --- |
| [`Cursor-01-chart-stacked-bar`](Cursor/01-chart-stacked-bar.md) | 合算の推移に Cursor 系列が載る | done | E2E |
| [`Cursor-02-hero-side-by-side`](Cursor/02-hero-side-by-side.md) | 並べて表示でヒーロー下に Cursor 金額が並ぶ | done | E2E |
| [`Cursor-03-hero-cursor-only`](Cursor/03-hero-cursor-only.md) | Cursor のみでヒーローが Cursor 推定になる | done | E2E |
| [`Cursor-04-model-rows`](Cursor/04-model-rows.md) | モデル別に Cursor モデル行が出る | done | E2E |
| [`Cursor-05-top-session-rows`](Cursor/05-top-session-rows.md) | 高コストセッションに Cursor 行が混ざる | done | E2E |
| [`Cursor-06-session-estimated-label`](Cursor/06-session-estimated-label.md) | Cursor セッション行に推定表示が付く | done | E2E |
| [`Cursor-07-advice-dominant-model`](Cursor/07-advice-dominant-model.md) | Cursor のモデル偏りヒントが出る | done | E2E |
| [`Cursor-08-advice-share-of-total`](Cursor/08-advice-share-of-total.md) | Cursor の期間シェアヒントが出る | done | E2E |
| [`Cursor-09-advice-unpriced-models`](Cursor/09-advice-unpriced-models.md) | 価格表に無い Cursor モデルのヒントが出る | done | E2E |
| [`Cursor-10-advice-hidden-when-degraded`](Cursor/10-advice-hidden-when-degraded.md) | Cursor 取得劣化時は Cursor ヒントが出ない | done | E2E |
| [`Cursor-11-degraded-warning`](Cursor/11-degraded-warning.md) | Cursor 取得劣化時に警告が出る | done | E2E, VRT |
| [`Cursor-12-sign-in-open-app`](Cursor/12-sign-in-open-app.md) | サインアウト劣化時に Cursor を開ける | done | E2E, VRT |
| [`Cursor-13-recheck-after-sign-in`](Cursor/13-recheck-after-sign-in.md) | サインイン後にホームを開き直すと再取得する | done | E2E |
| [`Cursor-14-unavailable-dash-hero`](Cursor/14-unavailable-dash-hero.md) | Cursor のみかつ劣化でヒーローがダッシュになる | done | E2E |
| [`Cursor-15-unavailable-dash-menubar`](Cursor/15-unavailable-dash-menubar.md) | Cursor のみかつ劣化でメニューバーがダッシュになる | done | E2E |
| [`Cursor-16-unavailable-side-by-side`](Cursor/16-unavailable-side-by-side.md) | 並べて表示で Cursor 側だけダッシュになる | done | E2E |
| [`Cursor-17-filter-by-source-mode`](Cursor/17-filter-by-source-mode.md) | Claude のみのとき Cursor の行やヒントが隠れる | done | E2E |
| [`Cursor-18-zero-cost-hidden-breakdown`](Cursor/18-zero-cost-hidden-breakdown.md) | 0 円の Cursor は内訳キャプションに載らない | done | E2E |
