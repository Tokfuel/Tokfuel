import Ignite

@MainActor
func run() async throws {
    var site = TokfuelSite()
    try await site.publish()
}

try await run()
