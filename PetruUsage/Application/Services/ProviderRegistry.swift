import Foundation

final class ProviderRegistry {
    private let adapters: [Provider: UsageFetchingPort]

    init(
        httpClient: HTTPClientPort,
        keychain: KeychainPort,
        sqlite: SQLitePort
    ) {
        self.adapters = [
            .claude: ClaudeUsageAdapter(httpClient: httpClient, keychain: keychain),
            .cursor: CursorUsageAdapter(httpClient: httpClient, sqlite: sqlite),
            .codex: CodexUsageAdapter(httpClient: httpClient, keychain: keychain),
            .antigravity: AntigravityUsageAdapter(httpClient: httpClient, sqlite: sqlite),
            .kiro: KiroUsageAdapter(sqlite: sqlite),
            .openrouter: OpenRouterAdapter(httpClient: httpClient, keychain: keychain),
        ]
    }

    func adapter(for provider: Provider) -> UsageFetchingPort? {
        adapters[provider]
    }

    var allAdapters: [UsageFetchingPort] {
        Provider.allCases.compactMap { adapters[$0] }
    }
}
