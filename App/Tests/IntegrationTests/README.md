# IntegrationTests

結合テストを置く場所です。

いまは箱だけ確保している。追加するときは `Package.swift` に test target を足すか、
`UnitTests` とは別 target として切り出す。`swift test` の既定パス（`App/Tests/UnitTests`）には含めない。
