# E2E

アプリ向けの通しテスト実装を置く場所です。`swift test` の対象ではない。

シナリオ設計の正本は [`../TestDocs`](../TestDocs/) です。
ユニットは [`../UnitTests`](../UnitTests/)、結合は [`../IntegrationTests`](../IntegrationTests/) に置きます。

Maestro / Appium などのモバイル向けスタックは持ち込みません。macOS メニューバーアプリ向けの起動スモークや画面到達など、必要な範囲だけを後続 Issue で足します。
このディレクトリは配置の箱だけを先に確保しています。
