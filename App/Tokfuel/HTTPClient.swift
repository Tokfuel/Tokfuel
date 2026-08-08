import Foundation

/// 小さなHTTP取得口。成功ステータスの検証とテスト用注入を共通化する。
enum HTTPClient {
    typealias Performer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    enum Error: Swift.Error {
        case invalidResponse
        case unsuccessfulStatus(Int)
    }

    static func data(
        from url: URL,
        perform: Performer? = nil
    ) async throws -> Data {
        let request = URLRequest(url: url)
        let result = try await (perform ?? defaultPerformer)(request)
        guard let response = result.1 as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw Error.unsuccessfulStatus(response.statusCode)
        }
        return result.0
    }

    private static let defaultPerformer: Performer = { request in
        try await URLSession.shared.data(for: request)
    }
}
