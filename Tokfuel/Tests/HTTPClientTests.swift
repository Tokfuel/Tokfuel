import Foundation
import Testing
@testable import Tokfuel

struct HTTPClientTests {
    private let url = URL(string: "https://example.com/data")!

    @Test func 成功ステータスの本文を返す() async throws {
        let data = try await HTTPClient.data(from: url) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("ok".utf8), response)
        }
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test func 失敗ステータスを受け付けない() async {
        await #expect(throws: HTTPClient.Error.self) {
            try await HTTPClient.data(from: url) { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            }
        }
    }
}
