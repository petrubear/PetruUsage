import Foundation

protocol SettingsPort {
    var enabledProviders: Set<Provider> { get set }
    var refreshInterval: TimeInterval { get set }
    var hideFromDock: Bool { get set }
    var startOnLogin: Bool { get set }
    var theme: AppTheme { get set }

    func isProviderEnabled(_ provider: Provider) -> Bool
    func setProviderEnabled(_ provider: Provider, enabled: Bool)
}
