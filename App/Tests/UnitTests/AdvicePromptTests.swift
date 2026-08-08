import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
@testable import Tokfuel

/// コピーされる文面の検査。貼った先で意味が通らないと、ボタンがあっても使われない。
struct AdvicePromptTests {
    private let advice = RetokReport.Advice(
        severity: "info",
        key: "cursor_dominant_model",
        title: "gpt-5 が Cursor コストの 72% を占めています",
        detail: "確認や小さな編集まで同じモデルで回すと、単価の差がそのまま金額の差になります。")

    @Test func 指摘と根拠と出どころがそのまま載る() {
        let text = AdvicePrompt.text(for: advice, source: "Cursor")
        #expect(text.contains(advice.title))
        #expect(text.contains(advice.detail))
        #expect(text.contains("出どころ: Cursor"))
    }

    @Test func 出どころは渡した値をそのまま使う() {
        // Claude 由来と Cursor 由来が同じリストに並ぶので、取り違えると助言の前提が壊れる。
        let text = AdvicePrompt.text(for: advice, source: "Claude")
        #expect(text.contains("出どころ: Claude"))
        #expect(!text.contains("出どころ: Cursor"))
    }

    @Test func 依頼として何を返すべきかを含む() {
        let text = AdvicePrompt.text(for: advice, source: "Claude")
        #expect(text.contains("# 依頼"))
        // 解釈・手順・確かめ方の 3 点を頼む形になっていること。
        #expect(text.contains("1. "))
        #expect(text.contains("2. "))
        #expect(text.contains("3. "))
    }

    @Test func 当てはまらないときに断る余地を残す() {
        // 指摘は推定なので、無条件に対策を出させると誤った前提のまま話が進む。
        let text = AdvicePrompt.text(for: advice, source: "Claude")
        #expect(text.contains("当てはまらない"))
    }

    @Test func 記法の取りこぼしがない() {
        let text = AdvicePrompt.text(for: advice, source: "Claude")
        // 継続行（\）の書き損じは、そのまま本文に円記号として出る。
        #expect(!text.contains("\\"))
        #expect(!text.hasSuffix("\n"))
    }
}
