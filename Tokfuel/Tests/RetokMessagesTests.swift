import Foundation
import Testing
@testable import Tokfuel

struct RetokMessagesTests {

    @Test func 言語タグを同梱ロケールへ正規化する() {
        #expect(RetokMessages.resolveLang("ja") == "ja")
        #expect(RetokMessages.resolveLang("ja_JP.UTF-8") == "ja")
        #expect(RetokMessages.resolveLang("en") == "en")
        #expect(RetokMessages.resolveLang("zh-CN") == "zh-CN")
        #expect(RetokMessages.resolveLang("zh_cn") == "zh-CN")
        // 基底言語のロケールが無ければ、その言語で始まる別名へフォールバック
        #expect(RetokMessages.resolveLang("zh") == "zh-CN")
        // 未知の言語は英語
        #expect(RetokMessages.resolveLang("xx") == "en")
        #expect(RetokMessages.resolveLang("") == "en")
    }

    @Test func プレースホルダを置換する() {
        let en = RetokMessages(lang: "en")
        let title = en.format("adv_fat_ctx_title",
                              params: ["count": "3", "limit": "120", "max": "250"])
        #expect(title == "3 sessions exceeded 120k tokens of context (max 250k)")
    }

    @Test func 同梱ロケールが英語文言を上書きする() {
        // Bundle.module から locales/ja.json を読めることのスモークテストを兼ねる
        let ja = RetokMessages(lang: "ja")
        let title = ja.format("adv_ok_title")
        #expect(title != RetokMessages.english["adv_ok_title"])
        #expect(!title.isEmpty)
    }

    @Test func 未知キーはキー文字列を返す() {
        let en = RetokMessages(lang: "en")
        #expect(en.format("nonexistent_key") == "nonexistent_key")
    }
}
