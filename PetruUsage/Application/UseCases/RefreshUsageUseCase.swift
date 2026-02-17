import Foundation

final class RefreshUsageUseCase {
    private let fetchAll: FetchAllUsageUseCase
    private let settings: SettingsPort

    init(fetchAll: FetchAllUsageUseCase, settings: SettingsPort) {
        self.fetchAll = fetchAll
        self.settings = settings
    }

    func startPeriodicRefresh(onUpdate: @escaping ([Provider: ProviderStatus]) -> Void) async {
        while !Task.isCancelled {
            let results = await fetchAll.execute()
            onUpdate(results)

            let interval = settings.refreshInterval
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}
