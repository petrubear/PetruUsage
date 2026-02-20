import XCTest
@testable import PetruUsage

@MainActor
final class UsageViewModelTests: XCTestCase {
    private func makeViewModel() -> (UsageViewModel, MockSettings) {
        let httpClient = MockHTTPClient()
        let keychain = MockKeychainService()
        let sqlite = MockSQLiteService()
        let settings = MockSettings()

        let registry = ProviderRegistry(httpClient: httpClient, keychain: keychain, sqlite: sqlite)
        let fetchAll = FetchAllUsageUseCase(registry: registry, settings: settings)
        let refresh = RefreshUsageUseCase(fetchAll: fetchAll, settings: settings)

        let vm = UsageViewModel(fetchAllUseCase: fetchAll, refreshUseCase: refresh, settings: settings)
        return (vm, settings)
    }

    func testInitialState() {
        let (vm, _) = makeViewModel()
        XCTAssertNil(vm.lastRefreshed)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertEqual(vm.sortedProviders.count, Provider.visibleCases.count)
    }

    func testEnabledProviders() {
        let (vm, settings) = makeViewModel()
        XCTAssertEqual(vm.enabledProviders.count, Provider.visibleCases.count)

        settings.setProviderEnabled(.kiro, enabled: false)
        vm.updateProviderVisibility()

        XCTAssertEqual(vm.enabledProviders.count, Provider.visibleCases.count - 1)
        XCTAssertFalse(vm.enabledProviders.contains(.kiro))
    }

    func testDisabledProviderStatus() {
        let (vm, settings) = makeViewModel()
        settings.setProviderEnabled(.kiro, enabled: false)
        vm.updateProviderVisibility()

        if case .disabled = vm.providerStatuses[.kiro] {
            // Expected
        } else {
            XCTFail("Expected disabled status for kiro")
        }
    }

    func testReEnableProvider() {
        let (vm, settings) = makeViewModel()
        settings.setProviderEnabled(.kiro, enabled: false)
        vm.updateProviderVisibility()

        settings.setProviderEnabled(.kiro, enabled: true)
        vm.updateProviderVisibility()

        if case .disabled = vm.providerStatuses[.kiro] {
            XCTFail("Should not be disabled after re-enabling")
        }
    }
}

final class MockSettings: SettingsPort {
    var enabledProviders: Set<Provider> = Set(Provider.allCases)
    var refreshInterval: TimeInterval = 300
    var hideFromDock: Bool = false
    var startOnLogin: Bool = false
    var theme: AppTheme = .system

    func isProviderEnabled(_ provider: Provider) -> Bool {
        enabledProviders.contains(provider)
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        if enabled {
            enabledProviders.insert(provider)
        } else {
            enabledProviders.remove(provider)
        }
    }
}
