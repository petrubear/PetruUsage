import Foundation
import AppKit
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {
    private var settings: SettingsPort
    private let onProvidersChanged: () -> Void
    private(set) var enabledProviders: Set<Provider>
    var orderedVisibleProviders: [Provider]
    var theme: AppTheme {
        didSet {
            settings.theme = theme
            NSApp.appearance = Self.appearance(for: theme)
        }
    }

    init(settings: SettingsPort, onProvidersChanged: @escaping () -> Void) {
        self.settings = settings
        self.onProvidersChanged = onProvidersChanged
        self.enabledProviders = settings.enabledProviders
        self.orderedVisibleProviders = settings.providerOrder
        self.theme = settings.theme

        // NSApp is nil during App.init(); defer until the run loop is live
        let storedTheme = settings.theme
        DispatchQueue.main.async {
            NSApp.appearance = Self.appearance(for: storedTheme)
        }
    }

    private static func appearance(for theme: AppTheme) -> NSAppearance? {
        switch theme {
        case .system: nil
        case .light:  NSAppearance(named: .aqua)
        case .dark:   NSAppearance(named: .darkAqua)
        }
    }

    var refreshIntervalMinutes: Double {
        get { settings.refreshInterval / 60 }
        set { settings.refreshInterval = newValue * 60 }
    }

    var hideFromDock: Bool {
        get { settings.hideFromDock }
        set {
            settings.hideFromDock = newValue
            NSApp.setActivationPolicy(newValue ? .accessory : .regular)
        }
    }

    var startOnLogin: Bool {
        get {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: return true
            default: return false
            }
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // SMAppService.mainApp.status is the source of truth;
                // the getter will reflect the actual state after this call
            }
        }
    }

    func isProviderEnabled(_ provider: Provider) -> Bool {
        enabledProviders.contains(provider)
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        settings.setProviderEnabled(provider, enabled: enabled)
        enabledProviders = settings.enabledProviders
        onProvidersChanged()
    }

    func moveProviders(from source: IndexSet, to destination: Int) {
        orderedVisibleProviders.move(fromOffsets: source, toOffset: destination)
        settings.setProviderOrder(orderedVisibleProviders)
        onProvidersChanged()
    }
}
