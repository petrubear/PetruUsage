import SwiftUI

@main
struct PetruUsageApp: App {
    @State private var usageViewModel: UsageViewModel
    @State private var settingsViewModel: SettingsViewModel

    private let settings: SettingsPort
    private let registry: ProviderRegistry

    init() {
        let httpClient = URLSessionHTTPClient()
        let keychain = KeychainService()
        let sqlite = SQLiteService()
        let settings: SettingsPort = UserDefaultsSettingsAdapter()

        let registry = ProviderRegistry(
            httpClient: httpClient,
            keychain: keychain,
            sqlite: sqlite
        )

        let fetchAllUseCase = FetchAllUsageUseCase(registry: registry, settings: settings)
        let refreshUseCase = RefreshUsageUseCase(fetchAll: fetchAllUseCase, settings: settings)

        let usageVM = UsageViewModel(
            fetchAllUseCase: fetchAllUseCase,
            refreshUseCase: refreshUseCase,
            settings: settings
        )

        let settingsVM = SettingsViewModel(settings: settings) {
            usageVM.updateProviderVisibility()
            usageVM.refreshAll()
        }

        self._usageViewModel = State(initialValue: usageVM)
        self._settingsViewModel = State(initialValue: settingsVM)
        self.settings = settings
        self.registry = registry

        // Apply dock visibility
        if settings.hideFromDock {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: usageViewModel)
        } label: {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 12))
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 320, height: 400)

        Window("Settings", id: "settings") {
            SettingsView(viewModel: settingsViewModel)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
