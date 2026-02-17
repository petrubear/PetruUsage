import Foundation

final class UserDefaultsSettingsAdapter: SettingsPort {
    private let defaults: UserDefaults
    private let enabledProvidersKey = "enabledProviders"
    private let refreshIntervalKey = "refreshInterval"
    private let hideFromDockKey = "hideFromDock"
    private let startOnLoginKey = "startOnLogin"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabledProviders: Set<Provider> {
        get {
            guard let rawValues = defaults.array(forKey: enabledProvidersKey) as? [String] else {
                return Set(Provider.allCases)
            }
            return Set(rawValues.compactMap { Provider(rawValue: $0) })
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: enabledProvidersKey)
        }
    }

    var refreshInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: refreshIntervalKey)
            return value > 0 ? value : 300
        }
        set {
            defaults.set(newValue, forKey: refreshIntervalKey)
        }
    }

    var hideFromDock: Bool {
        get { defaults.bool(forKey: hideFromDockKey) }
        set { defaults.set(newValue, forKey: hideFromDockKey) }
    }

    var startOnLogin: Bool {
        get { defaults.bool(forKey: startOnLoginKey) }
        set { defaults.set(newValue, forKey: startOnLoginKey) }
    }

    func isProviderEnabled(_ provider: Provider) -> Bool {
        enabledProviders.contains(provider)
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        var current = enabledProviders
        if enabled {
            current.insert(provider)
        } else {
            current.remove(provider)
        }
        enabledProviders = current
    }
}
