# シナリオ一覧（網羅確認用）

TestDocs の全シナリオをドメイン別に並べた索引です。網羅の抜け漏れ確認に使います。
個別シナリオの正本は各 MD、運用規約は [`AGENTS.md`](AGENTS.md)、手段の優先は [`coverage-strategy.md`](coverage-strategy.md) です。

このファイルはシナリオ MD から生成します。シナリオを足したら同じ手順で更新してください。

```bash
python3 Scripts/generate-testdocs-catalog.py
```

## 件数

| Domain | 件数 |
| --- | ---: |
| MenuBar | 33 |
| Cost | 26 |
| Settings | 36 |
| Budget | 18 |
| Cursor | 18 |
| **合計** | **131** |

## status の見方

| status | 意味 |
| --- | --- |
| `ideation` | 壁打ち中 |
| `ready` | 実装着手可 |
| `in-progress` | 実装中 |
| `review` | レビュー中 |
| `done` | 実装完了 |

## MenuBar（33）

| ID | title | status | 完了条件 | シナリオ要約 |
| --- | --- | --- | --- | --- |
| [`MenuBar-01-open-home`](MenuBar/01-open-home.md) | メニューバーからホーム（ポップオーバー）を表示できる | ready | E2E | ユーザーがメニューバーの Tokfuel アイコンを操作すると、ホーム相当のポップオーバーが開き、今日のコストと主要セクションを読めます。 |
| [`MenuBar-02-close-outside`](MenuBar/02-close-outside.md) | ホーム外をクリックするとポップオーバーが閉じる | ready | E2E | ユーザーがホーム（ポップオーバー）を開いたあと、他のアプリ側をクリックすると、ホームが閉じます。 |
| [`MenuBar-03-toggle-reopen`](MenuBar/03-toggle-reopen.md) | メニューバーアイコンの再操作でホームを閉じられる | ready | E2E | ユーザーがホームを開いた状態で、もう一度メニューバーのアイコンを操作すると、ホームが閉じます。 |
| [`MenuBar-04-hero-today-cost`](MenuBar/04-hero-today-cost.md) | ホームのヒーローに今日のコストが表示される | ready | E2E | ユーザーがホームを開くと、ヒーローに「今日」のラベルと大きな今日のコスト金額が表示されます。 |
| [`MenuBar-05-footer-last-updated`](MenuBar/05-footer-last-updated.md) | フッターに最終更新時刻が表示される | ready | E2E | ユーザーがホームを開くと、フッターに最終更新時刻（更新 HH:MM）が表示されます。 |
| [`MenuBar-06-footer-reload`](MenuBar/06-footer-reload.md) | 再読み込みで集計が更新される | ready | E2E, UT&IT | ユーザーがホームのメニューから「再読み込み」を選ぶと、集計が走り、表示が更新されます。 |
| [`MenuBar-07-footer-quit`](MenuBar/07-footer-quit.md) | メニューから Tokfuel を終了できる | ready | E2E | ユーザーがホームのメニューから「Tokfuel を終了」を選ぶと、アプリが終了します。 |
| [`MenuBar-08-open-about`](MenuBar/08-open-about.md) | メニューから Tokfuel についてを開ける | ready | E2E | ユーザーがホームのメニューから「Tokfuel について」を選ぶと、About ウィンドウが開きます。 |
| [`MenuBar-09-status-amount-today`](MenuBar/09-status-amount-today.md) | メニューバーに今日の金額が表示される | ready | E2E | 見る指標が「今日」のとき、メニューバーに今日のコスト金額が表示されます。 |
| [`MenuBar-10-status-amount-month`](MenuBar/10-status-amount-month.md) | メニューバーに今月の金額が表示される | ready | E2E | 見る指標が「今月」のとき、メニューバーに今月のコスト金額が表示されます。 |
| [`MenuBar-11-status-amount-both`](MenuBar/11-status-amount-both.md) | メニューバーに今日と今月の金額が表示される | ready | E2E | 見る指標が「今日と今月」のとき、メニューバーに両方の金額が表示されます。 |
| [`MenuBar-12-status-prompts`](MenuBar/12-status-prompts.md) | メニューバーにプロンプト数が表示される | ready | E2E | 見る指標が「プロンプト数」のとき、メニューバーにプロンプト数が表示されます。 |
| [`MenuBar-13-status-percent`](MenuBar/13-status-percent.md) | メニューバーにパーセント表示が出る | ready | E2E | 表現がパーセントのとき、メニューバーに消費率または残率の数値が表示されます。 |
| [`MenuBar-14-status-ring`](MenuBar/14-status-ring.md) | メニューバーにリングゲージだけが表示される | ready | E2E | 表現がリングのとき、メニューバーにリングゲージが表示され、数字だけの表示にはなりません。 |
| [`MenuBar-15-status-ring-and-value`](MenuBar/15-status-ring-and-value.md) | メニューバーにリングとパーセントが並ぶ | ready | E2E | 表現がリングとパーセントのとき、メニューバーにリングと数値が並んで表示されます。 |
| [`MenuBar-16-status-icon-only`](MenuBar/16-status-icon-only.md) | メニューバーがアイコンのみになる | ready | E2E | 表現がアイコンのみのとき、メニューバーはアイコンだけで、タイトル文字列は空になります。 |
| [`MenuBar-17-gauge-shape-ring`](MenuBar/17-gauge-shape-ring.md) | ゲージの形がリングのとき円形インジケーターになる | ready | E2E | ゲージの形がリングのとき、メニューバーのゲージは円形インジケーターとして描画されます。 |
| [`MenuBar-18-gauge-shape-tank`](MenuBar/18-gauge-shape-tank.md) | ゲージの形がタンクのとき給油機が下から塗られる | ready | E2E | ゲージの形がタンクのとき、メニューバーの給油機アイコンが下から塗られる形で割合を示します。 |
| [`MenuBar-19-ring-with-icon`](MenuBar/19-ring-with-icon.md) | リング表示時にアイコンも並べられる | ready | E2E | リング表示で「アイコンも並べる」がオンのとき、給油機アイコンとリングが横並びに表示されます。 |
| [`MenuBar-20-percent-basis-budget`](MenuBar/20-percent-basis-budget.md) | 割合の基準が予算上限のとき予算に対する率が表示される | ready | E2E, UT&IT | 割合の基準が予算上限のとき、メニューバーのパーセントは予算に対する消費率（または残率）になります。 |
| [`MenuBar-21-percent-basis-average`](MenuBar/21-percent-basis-average.md) | 割合の基準が日次平均のときペース比が表示される | ready | E2E, UT&IT | 割合の基準が過去 30 日の日次平均のとき、メニューバーのパーセントは平均に対するペース比になります。 |
| [`MenuBar-22-shows-remaining`](MenuBar/22-shows-remaining.md) | 予算までの残り表示に切り替えられる | ready | E2E | 「予算までの残りを表示」がオンのとき、メニューバーは残額または残率の表示になります。 |
| [`MenuBar-23-side-by-side-title`](MenuBar/23-side-by-side-title.md) | 並べて表示のときメニューバーにソース内訳が出る | ready | E2E | コストのソースが並べて表示のとき、メニューバーに Claude と二次ソースの内訳が並びます。 |
| [`MenuBar-24-unavailable-dash`](MenuBar/24-unavailable-dash.md) | 取得不能時メニューバーがダッシュになる | ready | E2E | 二次ソースのみなど取得不能な状態では、メニューバーは 0 円ではなく欠測のダッシュを表示します。 |
| [`MenuBar-25-budget-icon-warning`](MenuBar/25-budget-icon-warning.md) | 予算しきい値到達でメニューバーアイコンが警告色になる | ready | E2E | 予算の警告しきい値に達すると、メニューバーアイコンがオレンジ系の警告色になります。 |
| [`MenuBar-26-budget-icon-over`](MenuBar/26-budget-icon-over.md) | 予算超過でメニューバーアイコンが超過色になる | ready | E2E | 予算を超過すると、メニューバーアイコンが赤系の超過色になります。 |
| [`MenuBar-27-tooltip`](MenuBar/27-tooltip.md) | メニューバーアイコンのツールチップに指標説明が出る | ready | E2E | ユーザーがメニューバーアイコンにポインタを合わせると、ツールチップに現在の指標の説明が出ます。 |
| [`MenuBar-28-adaptive-glow`](MenuBar/28-adaptive-glow.md) | 追従中の明滅がメニューバーアイコンに出る | ready | E2E | 使用中は更新を速めるがオンで、明滅もオンのとき、追従モード中はメニューバーアイコンが明滅します。 |
| [`MenuBar-29-update-button-offer`](MenuBar/29-update-button-offer.md) | 新バージョン検出時にアップデートボタンが出る | ready | E2E | 新しいバージョンが検出されると、ホームのフッターにアップデートボタンが表示されます。 |
| [`MenuBar-30-update-skip-version`](MenuBar/30-update-skip-version.md) | 提示中のバージョンをスキップできる | ready | E2E | アップデート提示中に、そのバージョンをスキップすると、同じバージョンのボタンが消えます。 |
| [`MenuBar-31-update-release-page`](MenuBar/31-update-release-page.md) | 差し替え不可環境ではリリースページを開くに変わる | ready | E2E | その場差し替えができない環境では、フッター操作が「リリースページを開く」に差し替わります。 |
| [`MenuBar-32-update-retry`](MenuBar/32-update-retry.md) | 更新失敗時に再試行できる | ready | E2E | アップデート処理が失敗すると、フッターが警告表示と再試行操作になります。 |
| [`MenuBar-33-open-on-launch-reload`](MenuBar/33-open-on-launch-reload.md) | ホームを開いたときに集計が走って数字が新しくなる | ready | E2E | ユーザーがホームを開くと集計が走り、開いた直後の数字が最新の状態になります。 |

## Cost（26）

| ID | title | status | 完了条件 | シナリオ要約 |
| --- | --- | --- | --- | --- |
| [`Cost-01-chart-style`](Cost/01-chart-style.md) | 推移グラフの表示形式を切り替えられる | ready | E2E, VRT | ユーザーがホームの「推移」でグラフ形式を切り替えると、日別の棒グラフと累積の折れ線グラフを行き来できます。 |
| [`Cost-02-period-switch`](Cost/02-period-switch.md) | 推移の期間を切り替え、表示が期間に追従する | ready | E2E, UT&IT | ユーザーがホームの推移で期間を切り替えると、表示が選んだ期間（今日、今週、今月、今年）に合わせて変わります。 |
| [`Cost-03-model-list`](Cost/03-model-list.md) | モデル別セクションにモデル行が表示される | ready | E2E | ユーザーがホームを開くと、「モデル別」セクションにモデル名と金額の行が表示されます。 |
| [`Cost-04-loading-parse`](Cost/04-loading-parse.md) | レポート未取得時に解析中表示が出る | ready | E2E | レポートがまだ無いとき、ホームに「解析中…」の読み込み表示が出ます。 |
| [`Cost-05-stale-while-revalidate`](Cost/05-stale-while-revalidate.md) | 再解析中も前回のグラフが残る | ready | E2E | 再解析中は前回のグラフを表示したまま、右下などに小さな進行表示が出ます。 |
| [`Cost-06-retok-error`](Cost/06-retok-error.md) | retok 失敗時にエラー文が出る | ready | E2E | python3 が無いなど retok が失敗すると、ホームに警告ラベルでエラー文が出ます。設定やメニューバー自体は動き続けます。 |
| [`Cost-07-chart-multi-source-legend`](Cost/07-chart-multi-source-legend.md) | 複数ソース時に推移の凡例が出る | ready | E2E | 複数ソースがあるとき、日別棒グラフにソース別の凡例が表示されます。 |
| [`Cost-08-chart-caption-total`](Cost/08-chart-caption-total.md) | 推移キャプションに期間合計が出る | ready | E2E | 推移グラフの下キャプションに、選んだ期間の合計が表示されます。 |
| [`Cost-09-chart-caption-prompt-unit`](Cost/09-chart-caption-prompt-unit.md) | 推移キャプションにプロンプト単価が出る | ready | E2E | Claude を含みプロンプトがあるとき、推移キャプションにプロンプト単価が出ます。 |
| [`Cost-10-cumulative-budget-line`](Cost/10-cumulative-budget-line.md) | 累積グラフに予算の参照線が出る | ready | E2E | 累積表示かつ今月で、暦月の予算があるとき、グラフに予算の破線参照線とラベルが出ます。 |
| [`Cost-11-cumulative-month-projection`](Cost/11-cumulative-month-projection.md) | 累積キャプションに月末の着地予測が出る | ready | E2E | 累積表示かつ暦月予算のとき、キャプションに月末の着地予測が出ます。 |
| [`Cost-12-jpy-formatting`](Cost/12-jpy-formatting.md) | 円表示のときホームの金額が円表記になる | ready | E2E | 通貨が円のとき、ホーム内の金額や軸が円表記になります。 |
| [`Cost-13-side-by-side-caption`](Cost/13-side-by-side-caption.md) | 並べて表示でヒーロー下にソース内訳キャプションが出る | ready | E2E | コストのソースが並べて表示のとき、ヒーロー下に Claude と二次ソースの内訳キャプションが出ます。 |
| [`Cost-14-cursor-only-label`](Cost/14-cursor-only-label.md) | Cursor のみのときヒーローに Cursor 推定ラベルが出る | ready | E2E | コストのソースが Cursor のみのとき、ヒーローに Cursor（推定）のラベルが出ます。 |
| [`Cost-15-unavailable-hero-dash`](Cost/15-unavailable-hero-dash.md) | 取得不能時ヒーロー金額がダッシュになる | ready | E2E | 二次ソースのみで取得が劣化しているとき、ヒーロー金額はダッシュになります。 |
| [`Cost-16-model-breakdown-combined`](Cost/16-model-breakdown-combined.md) | モデル別をまとめて表示できる | ready | E2E | モデル別の出し方がまとめてのとき、ソースをまたいだモデルが一覧にマージされます。 |
| [`Cost-17-model-breakdown-separated`](Cost/17-model-breakdown-separated.md) | モデル別をソース別に分けて表示できる | ready | E2E | モデル別の出し方がソース別に分けるのとき、ソース見出し付きで分かれます。 |
| [`Cost-18-top-sessions`](Cost/18-top-sessions.md) | 高コストのセッション一覧が表示される | ready | E2E | ホームの「高コストのセッション」に、タイトルとソースと金額の行が出ます。 |
| [`Cost-19-session-estimated-badge`](Cost/19-session-estimated-badge.md) | 二次ソースのセッションに推定表示が付く | ready | E2E | 二次ソース由来のセッション行には、推定であることが分かる表示が付きます。 |
| [`Cost-20-advice-section`](Cost/20-advice-section.md) | 節約のヒントセクションが表示される | ready | E2E | ホームに「節約のヒント」セクションがあり、ヒント行が並びます。 |
| [`Cost-21-advice-expand`](Cost/21-advice-expand.md) | 節約のヒントを展開できる | ready | E2E | ユーザーがヒント行を操作すると、詳細テキストが展開されます。 |
| [`Cost-22-advice-copy-prompt`](Cost/22-advice-copy-prompt.md) | 改善プロンプトをコピーできる | ready | E2E | ヒント展開後に改善プロンプトをコピーすると、クリップボードに文面が入り、ラベルが一時的に変わります。 |
| [`Cost-23-advice-source-badge`](Cost/23-advice-source-badge.md) | 節約のヒントにソース表示が付く | ready | E2E | 各ヒント行に、Claude や Cursor などソースが分かる表示が付きます。 |
| [`Cost-24-csv-export-daily`](Cost/24-csv-export-daily.md) | 日別 CSV を書き出せる | ready | E2E | ホームのメニューから日別 CSV を書き出すと、保存パネルが開きファイルを保存できます。 |
| [`Cost-25-csv-export-monthly`](Cost/25-csv-export-monthly.md) | 月別 CSV を書き出せる | ready | E2E | ホームのメニューから月別 CSV を書き出すと、月次集計のファイルを保存できます。 |
| [`Cost-26-csv-export-disabled`](Cost/26-csv-export-disabled.md) | レポート未取得時は CSV 書き出しが無効になる | ready | E2E | レポートが未取得のとき、CSV を書き出すメニュー項目は無効になります。 |

## Settings（36）

| ID | title | status | 完了条件 | シナリオ要約 |
| --- | --- | --- | --- | --- |
| [`Settings-01-open`](Settings/01-open.md) | ポップオーバーから設定を開ける | ready | E2E | ユーザーがホームのメニューから「設定」を選ぶと、Tokfuel 設定のウィンドウが開きます。 |
| [`Settings-02-reflect`](Settings/02-reflect.md) | 設定の変更がポップオーバー／メニューバー表示に反映される | ready | E2E, UT&IT | ユーザーが設定を変えると、ホームやメニューバーの表示がその内容に合わせて変わります。 |
| [`Settings-03-launch-at-login`](Settings/03-launch-at-login.md) | ログイン時に自動起動を切り替えられる | ready | E2E | 設定の「ログイン時に自動起動」を切り替えると、ログイン項目の登録状態が変わります。 |
| [`Settings-04-appearance`](Settings/04-appearance.md) | 外観の切替が各ウィンドウに反映される | ready | E2E | 外観をシステム、ライト、ダークのあいだで切り替えると、ホームと設定と About の見え方が追従します。 |
| [`Settings-05-cost-source-combined`](Settings/05-cost-source-combined.md) | コストのソースを合算にできる | ready | E2E | コストのソースを合算にすると、ホームは全ソース合計を表示します。 |
| [`Settings-06-cost-source-claude-only`](Settings/06-cost-source-claude-only.md) | コストのソースを Claude のみにできる | ready | E2E | コストのソースを Claude のみにすると、ホームは Claude のコストだけを表示します。 |
| [`Settings-07-cost-source-cursor-only`](Settings/07-cost-source-cursor-only.md) | コストのソースを Cursor のみにできる | ready | E2E | コストのソースを Cursor のみにすると、ホームは Cursor のコストだけを表示します。 |
| [`Settings-08-cost-source-codex-only`](Settings/08-cost-source-codex-only.md) | Codex がある環境で Codex のみを選べる | ready | E2E | Codex CLI がインストールされている Mac では、コストのソースに Codex のみを選べます。 |
| [`Settings-09-cost-source-side-by-side`](Settings/09-cost-source-side-by-side.md) | コストのソースを並べて表示にできる | ready | E2E | コストのソースを並べて表示にすると、ホームがソース別の内訳表示になります。 |
| [`Settings-10-model-breakdown-mode`](Settings/10-model-breakdown-mode.md) | モデル別の出し方を切り替えられる | ready | E2E | 設定のモデル別の出し方を、まとめてとソース別に分けるのあいだで切り替えられます。 |
| [`Settings-11-week-start`](Settings/11-week-start.md) | 週の始まりの変更が推移の今週に効く | ready | E2E, UT&IT | 週の始まりを変えると、推移の「今週」の範囲表示が変わります。 |
| [`Settings-12-menu-bar-metric`](Settings/12-menu-bar-metric.md) | メニューバーの見る指標を切り替えられる | ready | E2E | 見る指標を今日、今月、今日と今月、プロンプト数のあいだで切り替えられます。 |
| [`Settings-13-menu-bar-representation`](Settings/13-menu-bar-representation.md) | メニューバーの表現を切り替えられる | ready | E2E | 表現を金額、パーセント、リング、リングとパーセント、アイコンのみのあいだで、ライブプレビュー付きで選べます。 |
| [`Settings-14-menu-bar-gauge-shape`](Settings/14-menu-bar-gauge-shape.md) | ゲージの形をリングとタンクから選べる | ready | E2E | リング系の表現のとき、ゲージの形をリングとタンクから選べます。 |
| [`Settings-15-menu-bar-shows-icon`](Settings/15-menu-bar-shows-icon.md) | リング表示時にアイコンも並べるを切り替えられる | ready | E2E | リング表示のとき、「アイコンも並べる」を切り替えると、プレビューと実メニューバーが変わります。 |
| [`Settings-16-menu-bar-percent-basis`](Settings/16-menu-bar-percent-basis.md) | 割合の基準を切り替えられる | ready | E2E | 割合の基準を予算上限と過去 30 日の日次平均から選べます。 |
| [`Settings-17-menu-bar-shows-remaining`](Settings/17-menu-bar-shows-remaining.md) | 予算までの残りを表示を切り替えられる | ready | E2E | 「予算までの残りを表示」を切り替えると、メニューバーが残額または残率の見え方に変わります。 |
| [`Settings-18-adaptive-refresh`](Settings/18-adaptive-refresh.md) | 使用中は更新を速めるを切り替えられる | ready | E2E, UT&IT | 「使用中は更新を速める」を切り替えると、利用中の更新間隔の挙動が変わります。 |
| [`Settings-19-activity-animation`](Settings/19-activity-animation.md) | 追従中の明滅を切り替えられる | ready | E2E | 「速めている間アイコンを明滅させる」を切り替えられます。追従更新がオフのときは操作できません。 |
| [`Settings-20-budget-monthly-limit`](Settings/20-budget-monthly-limit.md) | 月の上限を設定できる | ready | E2E | 予算の「月の上限」に数値を入れると、ホームに月の予算ゲージが現れます。 |
| [`Settings-21-budget-daily-limit`](Settings/21-budget-daily-limit.md) | 1日の上限を設定できる | ready | E2E | 予算の「1日の上限」に数値を入れると、ホームに今日の予算行が現れます。 |
| [`Settings-22-budget-period`](Settings/22-budget-period.md) | 月予算の集計期間を切り替えられる | ready | E2E | 月の上限があるとき、集計期間を過去 30 日間と今月から選べます。 |
| [`Settings-23-budget-warn-threshold`](Settings/23-budget-warn-threshold.md) | 警告しきい値を切り替えられる | ready | E2E | 警告しきい値を 70%、80%、90% から選べます。 |
| [`Settings-24-budget-alert-style`](Settings/24-budget-alert-style.md) | 予算の知らせ方を切り替えられる | ready | E2E | 知らせ方を通知、アラートウィンドウ、通知とアラートウィンドウから選べます。 |
| [`Settings-25-privacy-analytics-toggle`](Settings/25-privacy-analytics-toggle.md) | 利用状況の送信許可を後から切り替えられる | ready | E2E | プライバシーの「利用状況の送信を許可」を後からオンオフできます。 |
| [`Settings-26-advanced-disclosure`](Settings/26-advanced-disclosure.md) | 詳細を開くと高度な設定が見える | ready | E2E | 設定の「詳細」を開くと、レポート言語や Claude ディレクトリなどが見えます。 |
| [`Settings-27-report-language`](Settings/27-report-language.md) | レポート言語を切り替えられる | ready | E2E | レポート言語を自動、English、日本語から選ぶと、節約のヒントなどの言語が追従します。 |
| [`Settings-28-claude-directory`](Settings/28-claude-directory.md) | Claude ディレクトリを変更しデフォルトに戻せる | ready | E2E | Claude ディレクトリを変更で選べ、デフォルトで戻せます。 |
| [`Settings-29-event-log-toggle`](Settings/29-event-log-toggle.md) | 利用イベントの記録を切り替えられる | ready | E2E | 「利用イベントを記録」をオンオフできます。 |
| [`Settings-30-event-log-reveal`](Settings/30-event-log-reveal.md) | イベントログフォルダを表示できる | ready | E2E | 「ログを表示」を選ぶと、Finder がイベントログのフォルダを開きます。 |
| [`Settings-31-event-log-delete`](Settings/31-event-log-delete.md) | 全イベントログを削除できる | ready | E2E | 「全イベントを削除」を選ぶと、ローカルのイベントログが消えます。 |
| [`Settings-32-about-window`](Settings/32-about-window.md) | About にバージョンとクレジットが見える | ready | E2E | About ウィンドウにバージョン、作者、retok や Frankfurter などのクレジットが見えます。 |
| [`Settings-33-analytics-consent-first-run`](Settings/33-analytics-consent-first-run.md) | 初回に利用状況送信の同意ダイアログが出る | ready | E2E | 初回起動時（未回答のとき）、利用状況の送信についての同意ダイアログが表示されます。 |
| [`Settings-34-analytics-consent-deny`](Settings/34-analytics-consent-deny.md) | 同意ダイアログで許可しないを選べる | ready | E2E | 同意ダイアログで「許可しない」を選ぶとダイアログが閉じ、送信設定はオフのままになります。 |
| [`Settings-35-menu-bar-preview-note`](Settings/35-menu-bar-preview-note.md) | 選べない表現のとき説明文が出る | ready | E2E | メニューバー節で、選べない表現や分母不足のとき、フッターに説明文が出ます。 |
| [`Settings-36-currency-jpy-budget-unit`](Settings/36-currency-jpy-budget-unit.md) | 円とレート取得後に予算入力の単位が円になる | ready | E2E | 通貨が円でレートが取れたあと、予算入力欄の単位が円になります。 |

## Budget（18）

| ID | title | status | 完了条件 | シナリオ要約 |
| --- | --- | --- | --- | --- |
| [`Budget-01-popover-daily-row`](Budget/01-popover-daily-row.md) | 1日上限があるときホームに今日の予算行が出る | ready | E2E | 1日の上限が設定されているとき、ホームに予算（今日）の行とメーターが出ます。 |
| [`Budget-02-popover-monthly-row`](Budget/02-popover-monthly-row.md) | 月上限があるときホームに月の予算行が出る | ready | E2E | 月の上限が設定されているとき、ホームに予算（今月）または予算（30日）の行が出ます。 |
| [`Budget-03-popover-hidden-when-off`](Budget/03-popover-hidden-when-off.md) | 上限未設定のとき予算セクションが隠れている | ready | E2E | 日も月も上限が未設定のとき、ホームに予算セクションは出ません。 |
| [`Budget-04-meter-ok-state`](Budget/04-meter-ok-state.md) | 平常時の予算メーターに消費と上限が見える | ready | E2E | 予算の平常状態では、メーター付近に消費と上限が読めます。 |
| [`Budget-05-meter-warning-state`](Budget/05-meter-warning-state.md) | しきい値到達で予算メーターが警告状態になる | ready | E2E | 警告しきい値に達すると、メーターが警告色になり、残りが表示されます。 |
| [`Budget-06-meter-over-state`](Budget/06-meter-over-state.md) | 超過で予算メーターが超過状態になる | ready | E2E | 上限を超えると、メーターが超過色になり、超過額と警告アイコンが出ます。 |
| [`Budget-07-meter-warn-marker`](Budget/07-meter-warn-marker.md) | 予算メーターに警告しきい値の目盛りが出る | ready | E2E | 予算メーター上に、警告しきい値の目盛り線が引かれます。 |
| [`Budget-08-notification-warning`](Budget/08-notification-warning.md) | しきい値到達を通知で知らせる | ready | E2E | 知らせ方が通知のとき、しきい値到達で通知センターへ 1 回通知されます。 |
| [`Budget-09-notification-over`](Budget/09-notification-over.md) | 上限超過を通知で知らせる | ready | E2E | 知らせ方が通知のとき、上限超過で別内容の通知が 1 回出ます。 |
| [`Budget-10-alert-window-warning`](Budget/10-alert-window-warning.md) | しきい値到達をアラートウィンドウで知らせる | ready | E2E | 知らせ方がアラートウィンドウのとき、しきい値到達で警告アラートが前面に出ます。 |
| [`Budget-11-alert-window-over`](Budget/11-alert-window-over.md) | 超過時アラートが超過向けの見え方になる | ready | E2E | 超過時のアラートは、警告時とは異なる超過向けの見出しや色になります。 |
| [`Budget-12-alert-open-settings`](Budget/12-alert-open-settings.md) | アラートから予算設定を開ける | ready | E2E | アラートの「予算設定を開く」を選ぶと、設定ウィンドウが開きます。 |
| [`Budget-13-alert-close`](Budget/13-alert-close.md) | アラートを閉じられる | ready | E2E | アラートの「閉じる」を選ぶと、アラートウィンドウが消えます。 |
| [`Budget-14-alert-both-channels`](Budget/14-alert-both-channels.md) | 通知とアラートウィンドウの両方で知らせる | ready | E2E | 知らせ方が通知とアラートウィンドウのとき、しきい値到達や超過で両方が出ます。 |
| [`Budget-15-daily-vs-monthly-independent`](Budget/15-daily-vs-monthly-independent.md) | 日次と月次の予算が独立に判定される | ready | E2E, UT&IT | 日次予算と月次予算は、ホーム上で独立に判定され、独立に表示されます。 |
| [`Budget-16-side-by-side-still-combined`](Budget/16-side-by-side-still-combined.md) | 並べて表示でも予算の分母は合算のまま | ready | E2E, UT&IT | コストのソースが並べて表示でも、予算ゲージの分母は合算コストのままです。 |
| [`Budget-17-auth-on-budget-set`](Budget/17-auth-on-budget-set.md) | 予算を初めて設定すると通知許可が求められる | ready | E2E | 予算上限を初めて設定すると、通知許可のダイアログが求められます。 |
| [`Budget-18-period-reset-notify`](Budget/18-period-reset-notify.md) | 日付や月が替わると同じレベルでも再通知できる | ready | E2E, UT&IT | 日付や月が替わると、同じ警告レベルでも改めて通知できます。 |

## Cursor（18）

| ID | title | status | 完了条件 | シナリオ要約 |
| --- | --- | --- | --- | --- |
| [`Cursor-01-chart-stacked-bar`](Cursor/01-chart-stacked-bar.md) | 合算の推移に Cursor 系列が載る | ready | E2E | 合算モードで複数ソースがあるとき、推移の日別棒に Cursor 系列が色分けで載ります。 |
| [`Cursor-02-hero-side-by-side`](Cursor/02-hero-side-by-side.md) | 並べて表示でヒーロー下に Cursor 金額が並ぶ | ready | E2E | 並べて表示のとき、ヒーロー下キャプションに Cursor の金額が並びます。 |
| [`Cursor-03-hero-cursor-only`](Cursor/03-hero-cursor-only.md) | Cursor のみでヒーローが Cursor 推定になる | ready | E2E | Cursor のみのとき、ヒーローは Cursor の推定コストだけを示します。 |
| [`Cursor-04-model-rows`](Cursor/04-model-rows.md) | モデル別に Cursor モデル行が出る | ready | E2E | Cursor のモデル内訳があるとき、モデル別に Cursor のモデル行が出ます。ソース別のときは Cursor 見出しの下に出ます。 |
| [`Cursor-05-top-session-rows`](Cursor/05-top-session-rows.md) | 高コストセッションに Cursor 行が混ざる | ready | E2E | Cursor の会話があるとき、高コストのセッションに Cursor 行がコスト順で混ざります。 |
| [`Cursor-06-session-estimated-label`](Cursor/06-session-estimated-label.md) | Cursor セッション行に推定表示が付く | ready | E2E | Cursor のセッション行には、Cursor（推定）であることが分かる表示が付きます。 |
| [`Cursor-07-advice-dominant-model`](Cursor/07-advice-dominant-model.md) | Cursor のモデル偏りヒントが出る | ready | E2E | 条件を満たすとき、節約のヒントに Cursor 由来のモデル偏りヒントが出ます。 |
| [`Cursor-08-advice-share-of-total`](Cursor/08-advice-share-of-total.md) | Cursor の期間シェアヒントが出る | ready | E2E | 条件を満たすとき、期間コストに占める Cursor の割合ヒントが出ます。 |
| [`Cursor-09-advice-unpriced-models`](Cursor/09-advice-unpriced-models.md) | 価格表に無い Cursor モデルのヒントが出る | ready | E2E | 価格表に無い Cursor モデルがあるとき、高い重要度のヒントが出ます。 |
| [`Cursor-10-advice-hidden-when-degraded`](Cursor/10-advice-hidden-when-degraded.md) | Cursor 取得劣化時は Cursor ヒントが出ない | ready | E2E | Cursor の取得が劣化しているとき、節約のヒントに Cursor 由来の行は出ません。 |
| [`Cursor-11-degraded-warning`](Cursor/11-degraded-warning.md) | Cursor 取得劣化時に警告が出る | ready | E2E | Cursor の取得が劣化しているとき、ヒーロー下に警告文と警告アイコンが出ます。 |
| [`Cursor-12-sign-in-open-app`](Cursor/12-sign-in-open-app.md) | サインアウト劣化時に Cursor を開ける | ready | E2E | サインアウト相当の劣化のとき、「Cursor を開く」で Cursor アプリを前面に出せます。 |
| [`Cursor-13-recheck-after-sign-in`](Cursor/13-recheck-after-sign-in.md) | サインイン後にホームを開き直すと再取得する | ready | E2E | サインインしたあとホームを開き直すと、Cursor の再取得が走ります。 |
| [`Cursor-14-unavailable-dash-hero`](Cursor/14-unavailable-dash-hero.md) | Cursor のみかつ劣化でヒーローがダッシュになる | ready | E2E | Cursor のみで取得劣化のとき、ヒーロー金額はダッシュになります。 |
| [`Cursor-15-unavailable-dash-menubar`](Cursor/15-unavailable-dash-menubar.md) | Cursor のみかつ劣化でメニューバーがダッシュになる | ready | E2E | Cursor のみで取得劣化のとき、メニューバーもダッシュになります。 |
| [`Cursor-16-unavailable-side-by-side`](Cursor/16-unavailable-side-by-side.md) | 並べて表示で Cursor 側だけダッシュになる | ready | E2E | 並べて表示で Cursor だけ劣化しているとき、Cursor 側だけダッシュになります。 |
| [`Cursor-17-filter-by-source-mode`](Cursor/17-filter-by-source-mode.md) | Claude のみのとき Cursor の行やヒントが隠れる | ready | E2E | コストのソースが Claude のみのとき、Cursor のモデル行、セッション、ヒントは出ません。 |
| [`Cursor-18-zero-cost-hidden-breakdown`](Cursor/18-zero-cost-hidden-breakdown.md) | 0 円の Cursor は内訳キャプションに載らない | ready | E2E | Cursor が 0 円のとき、並べて表示の内訳キャプションに Cursor は載りません。 |

## 面ごとの確認チェック

実装の UI 面と、対応するシナリオ群です。空欄や薄いところがあれば起票漏れの候補です。

| 面 | 想定シナリオ |
| --- | --- |
| メニューバー開閉 | `MenuBar-01` … `03`, `33` |
| ホームヒーロー / フッター | `MenuBar-04` … `08` |
| メニューバー指標 / 表現 / ゲージ | `MenuBar-09` … `23`, `Settings-12` … `19` |
| アップデート導線 | `MenuBar-29` … `32` |
| 推移グラフ / 期間 | `Cost-01`, `02`, `07` … `11` |
| 読み込み / エラー / CSV | `Cost-04` … `06`, `24` … `26` |
| モデル別 / セッション / ヒント | `Cost-03`, `16` … `23` |
| 設定一般 / ソース / 外観 | `Settings-01` … `11`, `36` |
| 設定の予算 / プライバシー / 詳細 | `Settings-20` … `35` |
| 予算メーター / 通知 / アラート | `Budget-01` … `18` |
| Cursor 表示 / 劣化 / ヒント | `Cursor-01` … `18` |

## 意図的な対象外

- Cursor included 枠の専用 UI（未実装）
- DEBUG 専用のデバッグ節
- 利用データを Mac の外へ出す検証
- Site（`Site/`）
