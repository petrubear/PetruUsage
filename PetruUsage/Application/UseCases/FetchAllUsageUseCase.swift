import Foundation

final class FetchAllUsageUseCase {
    private let registry: ProviderRegistry
    private let settings: SettingsPort

    init(registry: ProviderRegistry, settings: SettingsPort) {
        self.registry = registry
        self.settings = settings
    }

    func execute() async -> [Provider: ProviderStatus] {
        let enabledProviders = Provider.visibleCases.filter { settings.isProviderEnabled($0) }
        let adapters: [(Provider, UsageFetchingPort)] = enabledProviders.compactMap { provider in
            guard let adapter = registry.adapter(for: provider) else { return nil }
            return (provider, adapter)
        }

        return await withTaskGroup(of: (Provider, ProviderStatus).self) { group in
            for (provider, adapter) in adapters {
                let p = provider
                let a = adapter
                group.addTask {
                    do {
                        let result = try await a.fetchUsage()
                        return (p, .loaded(result))
                    } catch {
                        return (p, .error(error.localizedDescription))
                    }
                }
            }

            var results: [Provider: ProviderStatus] = [:]

            // Mark disabled providers
            for provider in Provider.visibleCases where !enabledProviders.contains(provider) {
                results[provider] = .disabled
            }

            for await (provider, status) in group {
                results[provider] = status
            }

            return results
        }
    }
}
