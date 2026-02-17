import Foundation
import SwiftUI

@Observable
@MainActor
final class UsageViewModel {
    private(set) var providerStatuses: [Provider: ProviderStatus] = [:]
    private(set) var lastRefreshed: Date?
    private(set) var isRefreshing = false

    private let fetchAllUseCase: FetchAllUsageUseCase
    private let refreshUseCase: RefreshUsageUseCase
    private let settings: SettingsPort
    private var refreshTask: Task<Void, Never>?

    init(
        fetchAllUseCase: FetchAllUsageUseCase,
        refreshUseCase: RefreshUsageUseCase,
        settings: SettingsPort
    ) {
        self.fetchAllUseCase = fetchAllUseCase
        self.refreshUseCase = refreshUseCase
        self.settings = settings

        // Initialize visible providers
        for provider in Provider.visibleCases {
            providerStatuses[provider] = settings.isProviderEnabled(provider) ? .idle : .disabled
        }
    }

    var enabledProviders: [Provider] {
        Provider.visibleCases.filter { settings.isProviderEnabled($0) }
    }

    var sortedProviders: [Provider] {
        Provider.visibleCases.filter { !(providerStatuses[$0]?.isDisabled ?? false) }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshUseCase.startPeriodicRefresh { [weak self] results in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.providerStatuses.merge(results) { _, new in new }
                    self.lastRefreshed = Date()
                    self.isRefreshing = false
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshAll() {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Set loading state for enabled providers
        for provider in enabledProviders {
            providerStatuses[provider] = .loading
        }

        Task {
            let results = await fetchAllUseCase.execute()
            providerStatuses.merge(results) { _, new in new }
            lastRefreshed = Date()
            isRefreshing = false
        }
    }

    func updateProviderVisibility() {
        for provider in Provider.visibleCases {
            if !settings.isProviderEnabled(provider) {
                providerStatuses[provider] = .disabled
            } else if providerStatuses[provider]?.isDisabled == true {
                providerStatuses[provider] = .idle
            }
        }
    }
}
