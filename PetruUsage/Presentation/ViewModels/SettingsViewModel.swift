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
        settings.isProviderEnabled(provider)
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        settings.setProviderEnabled(provider, enabled: enabled)
        onProvidersChanged()
    }
}
