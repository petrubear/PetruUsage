import Foundation
import AppKit
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {
    private var settings: SettingsPort
    private let onProvidersChanged: () -> Void

    init(settings: SettingsPort, onProvidersChanged: @escaping () -> Void) {
        self.settings = settings
        self.onProvidersChanged = onProvidersChanged
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
        get { settings.startOnLogin }
        set {
            settings.startOnLogin = newValue
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert on failure
                settings.startOnLogin = !newValue
            }
        }
    }

    func isProviderEnabled(_ provider: Provider) -> Bool {
        settings.isProviderEnabled(provider)
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        settings.setProviderEnabled(provider, enabled: enabled)
        onProvidersChanged()
    }
}
