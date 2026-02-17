import Foundation

final class FetchProviderUsageUseCase {
    private let registry: ProviderRegistry

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    func execute(provider: Provider) async -> ProviderStatus {
        guard let adapter = registry.adapter(for: provider) else {
            return .error("Provider not available")
        }

        do {
            let result = try await adapter.fetchUsage()
            return .loaded(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
